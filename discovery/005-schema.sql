-- ============================================
-- Sessions Table Migration
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- Sessions Table
-- ============================================
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    dialogflow_session_id VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    message_count INTEGER DEFAULT 0,
    language_code VARCHAR(10) DEFAULT 'uk',
    gcs_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_status CHECK (status IN ('active', 'ended', 'expired'))
);

-- ============================================
-- Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_dialogflow ON sessions(dialogflow_session_id);
CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at DESC);

-- ============================================
-- Updated At Trigger
-- ============================================
DROP TRIGGER IF EXISTS update_sessions_updated_at ON sessions;
CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Comments
-- ============================================
COMMENT ON TABLE sessions IS 'Chat session metadata - full conversations stored in GCS';
COMMENT ON COLUMN sessions.user_id IS 'User who created the session (null for anonymous)';
COMMENT ON COLUMN sessions.dialogflow_session_id IS 'Dialogflow CX session identifier';
COMMENT ON COLUMN sessions.status IS 'Session status: active, ended, expired';
COMMENT ON COLUMN sessions.message_count IS 'Number of messages in the session';
COMMENT ON COLUMN sessions.language_code IS 'Language code for the session (uk, en, ru)';
COMMENT ON COLUMN sessions.gcs_path IS 'Path to conversation data in GCS bucket';

-- ============================================
-- Session Messages Table Migration
-- ============================================
-- Stores individual messages to survive server restarts
-- 
-- Lifecycle:
-- 1. Messages stored here while session is active
-- 2. On session end: messages saved to GCS, then deleted from DB
-- 3. This ensures zero data loss even if server crashes
-- 4. Database stays clean - only active session messages kept

-- ============================================
-- Session Messages Table
-- ============================================
CREATE TABLE IF NOT EXISTS session_messages (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Technical details from Dialogflow CX (stored as JSONB for querying)
    intent_info JSONB,
    match_info JSONB,
    generative_info JSONB,
    webhook_statuses JSONB,
    diagnostic_info JSONB,
    sentiment JSONB,
    flow_info JSONB,
    response_time_ms INTEGER,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_session_messages_session_id ON session_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_session_messages_timestamp ON session_messages(timestamp);
CREATE INDEX IF NOT EXISTS idx_session_messages_created_at ON session_messages(created_at);

-- ============================================
-- Comments
-- ============================================
COMMENT ON TABLE session_messages IS 'Individual chat messages - persisted to survive server restarts';
COMMENT ON COLUMN session_messages.session_id IS 'Reference to parent session';
COMMENT ON COLUMN session_messages.role IS 'Message sender: user or assistant';
COMMENT ON COLUMN session_messages.intent_info IS 'Intent information from Dialogflow CX';
COMMENT ON COLUMN session_messages.generative_info IS 'RAG and Chain of Thought data';
COMMENT ON COLUMN session_messages.diagnostic_info IS 'Advanced diagnostic information';

-- ============================================
-- Add Feedback Column to Session Messages
-- ============================================
-- Adds user feedback (rating 1-5 and optional comment) to messages
-- NULL for backward compatibility with existing messages

-- Add feedback column
ALTER TABLE session_messages 
ADD COLUMN IF NOT EXISTS feedback JSONB;

-- Add comment
COMMENT ON COLUMN session_messages.feedback IS 'User feedback on message: {rating: 1-5, comment: string | null, submittedAt: ISO timestamp}';

-- ============================================
-- Session Moderation (statuses, tags, annotations)
-- ============================================

-- 1) Add moderation status to sessions
ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending';

DO $$
BEGIN
  ALTER TABLE sessions
    ADD CONSTRAINT sessions_moderation_status_check
    CHECK (moderation_status IN ('pending', 'in_review', 'moderated'));
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_sessions_moderation_status ON sessions(moderation_status);

COMMENT ON COLUMN sessions.moderation_status IS 'Moderation status: pending, in_review, moderated';

-- 2) Tags catalog
CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category VARCHAR(20) NOT NULL,
  color VARCHAR(20) NOT NULL DEFAULT '#3b82f6',
  description TEXT NOT NULL DEFAULT '',
  is_custom BOOLEAN NOT NULL DEFAULT FALSE,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT tags_category_check CHECK (category IN ('session', 'message')),
  CONSTRAINT tags_name_category_unique UNIQUE (name, category)
);

DROP TRIGGER IF EXISTS update_tags_updated_at ON tags;
CREATE TRIGGER update_tags_updated_at
  BEFORE UPDATE ON tags
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_tags_category ON tags(category);
CREATE INDEX IF NOT EXISTS idx_tags_usage_count ON tags(usage_count DESC);

COMMENT ON TABLE tags IS 'Tag definitions for moderation (session/message)';

-- 3) Session tags (many-to-many)
CREATE TABLE IF NOT EXISTS session_tags (
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  added_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (session_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_session_tags_session_id ON session_tags(session_id);
CREATE INDEX IF NOT EXISTS idx_session_tags_tag_id ON session_tags(tag_id);

COMMENT ON TABLE session_tags IS 'Tags applied to sessions';

-- 4) Annotations (session or message level)
CREATE TABLE IF NOT EXISTS annotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  message_id UUID,
  author_id UUID REFERENCES users(id) ON DELETE SET NULL,
  quality_rating SMALLINT NOT NULL,
  golden_reference TEXT,
  notes TEXT NOT NULL DEFAULT '',
  tags TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT annotations_quality_rating_check CHECK (quality_rating BETWEEN 1 AND 5)
);

DROP TRIGGER IF EXISTS update_annotations_updated_at ON annotations;
CREATE TRIGGER update_annotations_updated_at
  BEFORE UPDATE ON annotations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_annotations_session_id ON annotations(session_id);
CREATE INDEX IF NOT EXISTS idx_annotations_message_id ON annotations(message_id);
CREATE INDEX IF NOT EXISTS idx_annotations_created_at ON annotations(created_at DESC);

COMMENT ON TABLE annotations IS 'Moderator annotations (session/message level) with golden references and notes';

-- ============================================
-- Add guest_id to sessions
-- ============================================
-- We use guest_id to track guest (non-UUID) identities without violating
-- the sessions.user_id UUID foreign key constraint.

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS guest_id TEXT;

CREATE INDEX IF NOT EXISTS idx_sessions_guest_id ON sessions(guest_id);

COMMENT ON COLUMN sessions.guest_id IS 'Ephemeral guest identifier (starts with guest_). Null for authenticated sessions.';

-- ============================================
-- Delete empty (0-message) sessions
-- ============================================
-- "Empty session" definition:
-- - message_count is 0 (or NULL)
-- - there are no rows in session_messages
--
-- This will NOT delete ended sessions that had messages and were later
-- offloaded to GCS because those sessions have message_count > 0.

DELETE FROM sessions s
WHERE COALESCE(s.message_count, 0) = 0
  AND NOT EXISTS (
    SELECT 1
    FROM session_messages m
    WHERE m.session_id = s.id
  )
  AND NOT EXISTS (
    SELECT 1
    FROM session_reviews sr
    WHERE sr.session_id = s.id
  );

-- ============================================
-- Add last_activity_at to sessions (for TTL)
-- ============================================
-- We use last_activity_at to track real user activity (messages), so we can:
-- - expire sessions after 24h of inactivity
-- - avoid relying on updated_at (which can change due to admin/moderation updates)

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP WITH TIME ZONE;

-- Backfill for existing rows (best-effort)
UPDATE sessions
SET last_activity_at = COALESCE(last_activity_at, updated_at, started_at)
WHERE last_activity_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_last_activity_at ON sessions(last_activity_at DESC);

COMMENT ON COLUMN sessions.last_activity_at IS 'Last meaningful activity time (used for session TTL / expiry)';

-- ============================================
-- Add System Prompts Column to Session Messages
-- ============================================
-- Stores system prompts (e.g., agent memory messages) used for an assistant turn.
-- NULL for backward compatibility with existing messages.

ALTER TABLE session_messages
ADD COLUMN IF NOT EXISTS system_prompts JSONB;

COMMENT ON COLUMN session_messages.system_prompts IS 'System prompts used for this turn (debug/moderation). Example: { agentMemorySystemMessages: [{role:"system", content:"...", meta:{...}}] }';

-- ============================================
-- Allow system messages in session_messages.role
-- ============================================
-- Needed for non-blocking memory updates that append persisted system markers
-- and for compatibility with future system-level events.

DO $$
BEGIN
  IF to_regclass('public.session_messages') IS NULL THEN
    -- Table doesn't exist yet; nothing to do.
    RETURN;
  END IF;

  -- Default auto-generated constraint name for inline CHECK on column `role`
  -- is usually `session_messages_role_check`.
  EXECUTE 'ALTER TABLE session_messages DROP CONSTRAINT IF EXISTS session_messages_role_check';

  EXECUTE $sql$
    ALTER TABLE session_messages
      ADD CONSTRAINT session_messages_role_check
      CHECK (role IN ('user', 'assistant', 'system'))
  $sql$;
END $$;


-- ============================================
-- Groups + group scoping (users, sessions)
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- Groups table
-- ============================================
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_groups_name ON groups(name);

-- Keep updated_at consistent
DROP TRIGGER IF EXISTS update_groups_updated_at ON groups;
CREATE TRIGGER update_groups_updated_at
    BEFORE UPDATE ON groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE groups IS 'User groups for scoped administration and analytics';
COMMENT ON COLUMN groups.name IS 'Human-readable group name';

-- ============================================
-- Users: add group_id + extend role enum constraint
-- ============================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_users_group_id ON users(group_id);

-- Base schema defines a named constraint "valid_role"; extend it to include group_admin
ALTER TABLE users DROP CONSTRAINT IF EXISTS valid_role;
ALTER TABLE users
  ADD CONSTRAINT valid_role CHECK (role IN ('user', 'qa_specialist', 'researcher', 'moderator', 'owner', 'group_admin'));

COMMENT ON COLUMN users.group_id IS 'Optional group assignment for scoped administration';

-- ============================================
-- Sessions: add group_id (copied from user on session creation)
-- ============================================
ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_group_id ON sessions(group_id);

-- Best-effort backfill for existing sessions (only authenticated sessions)
UPDATE sessions s
SET group_id = u.group_id
FROM users u
WHERE s.group_id IS NULL
  AND s.user_id IS NOT NULL
  AND u.id = s.user_id
  AND u.group_id IS NOT NULL;

COMMENT ON COLUMN sessions.group_id IS 'Group snapshot for this session (copied from users.group_id)';

-- ============================================
-- Group memberships (multi-group roles) + invites + archiving
-- ============================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- Groups: archiving
-- ============================================
ALTER TABLE groups
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS archived_by UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_groups_archived_at ON groups(archived_at);

COMMENT ON COLUMN groups.archived_at IS 'When the group was archived (null = active)';
COMMENT ON COLUMN groups.archived_by IS 'User who archived the group';

-- ============================================
-- Users: active group selection (for UI context)
-- ============================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS active_group_id UUID REFERENCES groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_users_active_group_id ON users(active_group_id);

COMMENT ON COLUMN users.active_group_id IS 'Selected/active group context for the user (optional)';

-- Best-effort backfill from legacy users.group_id
UPDATE users
SET active_group_id = group_id
WHERE active_group_id IS NULL
  AND group_id IS NOT NULL;

-- ============================================
-- Group memberships (multi-group)
-- ============================================
CREATE TABLE IF NOT EXISTS group_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL DEFAULT 'member',
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_group_membership_role CHECK (role IN ('member', 'admin')),
  CONSTRAINT valid_group_membership_status CHECK (status IN ('active', 'pending', 'rejected', 'removed'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_group_memberships_group_user ON group_memberships(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_group_memberships_user_id ON group_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_group_memberships_group_id ON group_memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_group_memberships_status ON group_memberships(status);

DROP TRIGGER IF EXISTS update_group_memberships_updated_at ON group_memberships;
CREATE TRIGGER update_group_memberships_updated_at
  BEFORE UPDATE ON group_memberships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE group_memberships IS 'User membership in groups with per-group role and approval status';

-- Backfill memberships from legacy users.group_id (best-effort)
INSERT INTO group_memberships (user_id, group_id, role, status, approved_at, metadata)
SELECT
  u.id,
  u.group_id,
  CASE WHEN u.role = 'group_admin' THEN 'admin' ELSE 'member' END,
  'active',
  NOW(),
  jsonb_build_object('migratedFromUsersTable', true)
FROM users u
WHERE u.group_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM group_memberships gm WHERE gm.user_id = u.id AND gm.group_id = u.group_id
  );

-- ============================================
-- Group invite codes (for requesting access to a specific group)
-- ============================================
CREATE TABLE IF NOT EXISTS group_invite_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  code VARCHAR(64) UNIQUE NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  revoked_at TIMESTAMP WITH TIME ZONE,
  max_uses INTEGER NOT NULL DEFAULT 1,
  uses INTEGER NOT NULL DEFAULT 0,
  metadata JSONB DEFAULT '{}'::jsonb,
  CONSTRAINT valid_invite_max_uses CHECK (max_uses >= 1),
  CONSTRAINT valid_invite_uses CHECK (uses >= 0)
);

CREATE INDEX IF NOT EXISTS idx_group_invite_codes_group_id ON group_invite_codes(group_id);
CREATE INDEX IF NOT EXISTS idx_group_invite_codes_code ON group_invite_codes(code);

COMMENT ON TABLE group_invite_codes IS 'Invite codes that allow users to request access to a specific group';

-- ============================================
-- Access approval, multi-group memberships, settings
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- Users: approval/disapproval fields + status enum extension
-- ============================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS disapproved_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS disapproval_comment TEXT;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS disapproval_count INTEGER NOT NULL DEFAULT 0;

-- Extend status constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS valid_status;
ALTER TABLE users
  ADD CONSTRAINT valid_status CHECK (status IN ('active', 'blocked', 'pending', 'approval', 'disapproved', 'anonymized'));

-- ============================================
-- Global settings (single row)
-- ============================================
CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    guest_mode_enabled BOOLEAN NOT NULL DEFAULT false,
    approval_cooloff_days INTEGER NOT NULL DEFAULT 7,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_settings_singleton ON settings(id);

DROP TRIGGER IF EXISTS update_settings_updated_at ON settings;
CREATE TRIGGER update_settings_updated_at
    BEFORE UPDATE ON settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

INSERT INTO settings (id, guest_mode_enabled, approval_cooloff_days)
VALUES (1, false, 7)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Review system: structured peer review, risk
-- flagging, deanonymization, and crisis detection
-- ============================================

BEGIN;

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 1. session_reviews — per-reviewer assessment of a session
-- ============================================
CREATE TABLE IF NOT EXISTS session_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    reviewer_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_progress', 'completed', 'expired')),
    is_tiebreaker BOOLEAN NOT NULL DEFAULT false,
    average_score DECIMAL(3,1),
    overall_comment TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    config_snapshot JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT session_reviews_session_reviewer_unique UNIQUE (session_id, reviewer_id)
);

-- Indexes for session_reviews
CREATE INDEX IF NOT EXISTS idx_session_reviews_session_status
    ON session_reviews(session_id, status);
CREATE INDEX IF NOT EXISTS idx_session_reviews_reviewer_status
    ON session_reviews(reviewer_id, status);
CREATE INDEX IF NOT EXISTS idx_session_reviews_expires_at_active
    ON session_reviews(expires_at)
    WHERE status IN ('pending', 'in_progress');

-- Auto-update updated_at
DROP TRIGGER IF EXISTS update_session_reviews_updated_at ON session_reviews;
CREATE TRIGGER update_session_reviews_updated_at
    BEFORE UPDATE ON session_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE session_reviews IS 'Individual reviewer assessments of chat sessions';

-- ============================================
-- 2. message_ratings — per-message score within a review
-- ============================================
CREATE TABLE IF NOT EXISTS message_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES session_reviews(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES session_messages(id),
    score SMALLINT NOT NULL CHECK (score >= 1 AND score <= 10),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT message_ratings_review_message_unique UNIQUE (review_id, message_id)
);

-- Indexes for message_ratings
CREATE INDEX IF NOT EXISTS idx_message_ratings_review_id
    ON message_ratings(review_id);
CREATE INDEX IF NOT EXISTS idx_message_ratings_message_id
    ON message_ratings(message_id);

-- Auto-update updated_at
DROP TRIGGER IF EXISTS update_message_ratings_updated_at ON message_ratings;
CREATE TRIGGER update_message_ratings_updated_at
    BEFORE UPDATE ON message_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE message_ratings IS 'Per-message numeric scores given during a session review';

-- ============================================
-- 3. criteria_feedback — structured feedback per criterion
-- ============================================
CREATE TABLE IF NOT EXISTS criteria_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rating_id UUID NOT NULL REFERENCES message_ratings(id) ON DELETE CASCADE,
    criterion VARCHAR(20) NOT NULL
        CHECK (criterion IN ('relevance', 'empathy', 'safety', 'ethics', 'clarity')),
    feedback_text TEXT NOT NULL CHECK (LENGTH(feedback_text) >= 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT criteria_feedback_rating_criterion_unique UNIQUE (rating_id, criterion)
);

-- Indexes for criteria_feedback
CREATE INDEX IF NOT EXISTS idx_criteria_feedback_rating_id
    ON criteria_feedback(rating_id);

COMMENT ON TABLE criteria_feedback IS 'Criterion-level qualitative feedback on individual message ratings';

-- ============================================
-- 4. risk_flags — safety / compliance flags on sessions
-- ============================================
CREATE TABLE IF NOT EXISTS risk_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    flagged_by UUID REFERENCES users(id),
    severity VARCHAR(10) NOT NULL
        CHECK (severity IN ('high', 'medium', 'low')),
    reason_category VARCHAR(30) NOT NULL,
    details TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'acknowledged', 'resolved', 'escalated')),
    assigned_moderator_id UUID REFERENCES users(id),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    deanonymization_requested BOOLEAN NOT NULL DEFAULT false,
    is_auto_detected BOOLEAN NOT NULL DEFAULT false,
    matched_keywords TEXT[],
    sla_deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for risk_flags
CREATE INDEX IF NOT EXISTS idx_risk_flags_session_id
    ON risk_flags(session_id);
CREATE INDEX IF NOT EXISTS idx_risk_flags_severity_status
    ON risk_flags(severity, status);
CREATE INDEX IF NOT EXISTS idx_risk_flags_moderator_status
    ON risk_flags(assigned_moderator_id, status);
CREATE INDEX IF NOT EXISTS idx_risk_flags_sla_deadline_active
    ON risk_flags(sla_deadline)
    WHERE status IN ('open', 'acknowledged');

-- Auto-update updated_at
DROP TRIGGER IF EXISTS update_risk_flags_updated_at ON risk_flags;
CREATE TRIGGER update_risk_flags_updated_at
    BEFORE UPDATE ON risk_flags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE risk_flags IS 'Safety and compliance flags raised on chat sessions';

-- ============================================
-- 5. deanonymization_requests — controlled identity reveal
-- ============================================
CREATE TABLE IF NOT EXISTS deanonymization_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    target_user_id UUID NOT NULL REFERENCES users(id),
    requester_id UUID NOT NULL REFERENCES users(id),
    approver_id UUID REFERENCES users(id),
    risk_flag_id UUID REFERENCES risk_flags(id),
    justification_category VARCHAR(30) NOT NULL,
    justification_details TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'denied')),
    denial_notes TEXT,
    access_expires_at TIMESTAMPTZ,
    accessed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for deanonymization_requests
CREATE INDEX IF NOT EXISTS idx_deanonymization_requests_pending
    ON deanonymization_requests(status)
    WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_deanonymization_requests_requester
    ON deanonymization_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_deanonymization_requests_session
    ON deanonymization_requests(session_id);
CREATE INDEX IF NOT EXISTS idx_deanonymization_requests_access_expires
    ON deanonymization_requests(access_expires_at)
    WHERE status = 'approved';

-- Auto-update updated_at
DROP TRIGGER IF EXISTS update_deanonymization_requests_updated_at ON deanonymization_requests;
CREATE TRIGGER update_deanonymization_requests_updated_at
    BEFORE UPDATE ON deanonymization_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE deanonymization_requests IS 'Requests to reveal the real identity behind an anonymous session participant';

-- ============================================
-- 6. review_configuration — singleton settings for review system
-- ============================================
CREATE TABLE IF NOT EXISTS review_configuration (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    min_reviews SMALLINT NOT NULL DEFAULT 3,
    max_reviews SMALLINT NOT NULL DEFAULT 5,
    criteria_threshold SMALLINT NOT NULL DEFAULT 7,
    auto_flag_threshold SMALLINT NOT NULL DEFAULT 4,
    variance_limit DECIMAL(3,1) NOT NULL DEFAULT 2.0,
    timeout_hours SMALLINT NOT NULL DEFAULT 24,
    high_risk_sla_hours SMALLINT NOT NULL DEFAULT 2,
    medium_risk_sla_hours SMALLINT NOT NULL DEFAULT 24,
    deanonymization_access_hours SMALLINT NOT NULL DEFAULT 24,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

-- Auto-update updated_at
DROP TRIGGER IF EXISTS update_review_configuration_updated_at ON review_configuration;
CREATE TRIGGER update_review_configuration_updated_at
    BEFORE UPDATE ON review_configuration
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE review_configuration IS 'Singleton row holding review-system-wide thresholds and SLA settings';

-- ============================================
-- 7. crisis_keywords — keyword / phrase dictionary for auto-detection
-- ============================================
CREATE TABLE IF NOT EXISTS crisis_keywords (
    id SERIAL PRIMARY KEY,
    keyword TEXT NOT NULL,
    language VARCHAR(5) NOT NULL,
    category VARCHAR(30) NOT NULL
        CHECK (category IN ('suicidal_ideation', 'self_harm', 'violence', 'other')),
    severity VARCHAR(10) NOT NULL DEFAULT 'high'
        CHECK (severity IN ('high', 'medium')),
    is_phrase BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for crisis_keywords
CREATE INDEX IF NOT EXISTS idx_crisis_keywords_language_active
    ON crisis_keywords(language, is_active);
CREATE INDEX IF NOT EXISTS idx_crisis_keywords_category
    ON crisis_keywords(category);

COMMENT ON TABLE crisis_keywords IS 'Dictionary of keywords and phrases for automated crisis detection';

-- ============================================
-- 8. anonymous_mappings — real ↔ anonymous identity pairs
-- ============================================
CREATE TABLE IF NOT EXISTS anonymous_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    real_user_id UUID NOT NULL,
    anonymous_id VARCHAR(10) NOT NULL,
    context_session_id UUID NOT NULL REFERENCES sessions(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT anonymous_mappings_user_session_unique UNIQUE (real_user_id, context_session_id)
);

-- Indexes for anonymous_mappings
CREATE INDEX IF NOT EXISTS idx_anonymous_mappings_session
    ON anonymous_mappings(context_session_id);

COMMENT ON TABLE anonymous_mappings IS 'Maps real user IDs to anonymous identifiers within a session context';

-- ============================================
-- 9. review_notifications — in-app notification queue
-- ============================================
CREATE TABLE IF NOT EXISTS review_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES users(id),
    event_type VARCHAR(30) NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for review_notifications
CREATE INDEX IF NOT EXISTS idx_review_notifications_unread
    ON review_notifications(recipient_id, read_at)
    WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_review_notifications_event_created
    ON review_notifications(event_type, created_at);

COMMENT ON TABLE review_notifications IS 'In-app notifications for review events (assignments, completions, flags)';

-- ============================================
-- 10. ALTER sessions — add review & risk columns
-- ============================================
ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS review_status VARCHAR(20) DEFAULT 'pending_review';

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS review_final_score DECIMAL(3,1);

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS review_count SMALLINT NOT NULL DEFAULT 0;

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS reviews_required SMALLINT NOT NULL DEFAULT 3;

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS risk_level VARCHAR(10) DEFAULT 'none';

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS language VARCHAR(5);

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS auto_flagged BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS tiebreaker_reviewer_id UUID REFERENCES users(id);

-- Index on review_status for queue queries
CREATE INDEX IF NOT EXISTS idx_sessions_review_status
    ON sessions(review_status);

-- ============================================
-- 11. Seed review_configuration singleton row
-- ============================================
INSERT INTO review_configuration (
    id,
    min_reviews,
    max_reviews,
    criteria_threshold,
    auto_flag_threshold,
    variance_limit,
    timeout_hours,
    high_risk_sla_hours,
    medium_risk_sla_hours,
    deanonymization_access_hours
) VALUES (
    1, 3, 5, 7, 4, 2.0, 24, 2, 24, 24
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 12. Seed crisis_keywords — EN, UK, RU
-- ============================================

-- ---------- English (en) ----------

-- suicidal_ideation – en
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('suicide', 'en', 'suicidal_ideation', 'high', false),
    ('kill myself', 'en', 'suicidal_ideation', 'high', true),
    ('want to die', 'en', 'suicidal_ideation', 'high', true),
    ('end my life', 'en', 'suicidal_ideation', 'high', true),
    ('no reason to live', 'en', 'suicidal_ideation', 'high', true),
    ('suicidal thoughts', 'en', 'suicidal_ideation', 'high', true),
    ('better off dead', 'en', 'suicidal_ideation', 'high', true);

-- self_harm – en
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('self-harm', 'en', 'self_harm', 'high', false),
    ('cut myself', 'en', 'self_harm', 'high', true),
    ('hurt myself', 'en', 'self_harm', 'high', true),
    ('self-injury', 'en', 'self_harm', 'high', false),
    ('burning myself', 'en', 'self_harm', 'high', true),
    ('harming myself', 'en', 'self_harm', 'high', true);

-- violence – en
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('kill someone', 'en', 'violence', 'high', true),
    ('want to hurt', 'en', 'violence', 'high', true),
    ('going to attack', 'en', 'violence', 'high', true),
    ('bring a weapon', 'en', 'violence', 'high', true),
    ('murder', 'en', 'violence', 'high', false),
    ('shoot up', 'en', 'violence', 'high', true),
    ('bomb threat', 'en', 'violence', 'high', true);

-- ---------- Ukrainian (uk) ----------

-- suicidal_ideation – uk
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('суїцид', 'uk', 'suicidal_ideation', 'high', false),
    ('хочу померти', 'uk', 'suicidal_ideation', 'high', true),
    ('вбити себе', 'uk', 'suicidal_ideation', 'high', true),
    ('покінчити з життям', 'uk', 'suicidal_ideation', 'high', true),
    ('немає сенсу жити', 'uk', 'suicidal_ideation', 'high', true),
    ('суїцидальні думки', 'uk', 'suicidal_ideation', 'high', true),
    ('краще б мене не було', 'uk', 'suicidal_ideation', 'high', true);

-- self_harm – uk
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('самопошкодження', 'uk', 'self_harm', 'high', false),
    ('порізати себе', 'uk', 'self_harm', 'high', true),
    ('завдати собі болю', 'uk', 'self_harm', 'high', true),
    ('шкодити собі', 'uk', 'self_harm', 'high', true),
    ('ріжу себе', 'uk', 'self_harm', 'high', true),
    ('палити себе', 'uk', 'self_harm', 'high', true);

-- violence – uk
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('вбити когось', 'uk', 'violence', 'high', true),
    ('хочу нашкодити', 'uk', 'violence', 'high', true),
    ('напасти', 'uk', 'violence', 'high', false),
    ('зброя', 'uk', 'violence', 'medium', false),
    ('вбивство', 'uk', 'violence', 'high', false),
    ('погроза', 'uk', 'violence', 'medium', false),
    ('підірвати', 'uk', 'violence', 'high', false);

-- ---------- Russian (ru) ----------

-- suicidal_ideation – ru
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('суицид', 'ru', 'suicidal_ideation', 'high', false),
    ('хочу умереть', 'ru', 'suicidal_ideation', 'high', true),
    ('убить себя', 'ru', 'suicidal_ideation', 'high', true),
    ('покончить с собой', 'ru', 'suicidal_ideation', 'high', true),
    ('нет смысла жить', 'ru', 'suicidal_ideation', 'high', true),
    ('суицидальные мысли', 'ru', 'suicidal_ideation', 'high', true),
    ('лучше бы меня не было', 'ru', 'suicidal_ideation', 'high', true);

-- self_harm – ru
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('самоповреждение', 'ru', 'self_harm', 'high', false),
    ('порезать себя', 'ru', 'self_harm', 'high', true),
    ('причинить себе боль', 'ru', 'self_harm', 'high', true),
    ('навредить себе', 'ru', 'self_harm', 'high', true),
    ('режу себя', 'ru', 'self_harm', 'high', true),
    ('жгу себя', 'ru', 'self_harm', 'high', true);

-- violence – ru
INSERT INTO crisis_keywords (keyword, language, category, severity, is_phrase) VALUES
    ('убить кого-то', 'ru', 'violence', 'high', true),
    ('хочу навредить', 'ru', 'violence', 'high', true),
    ('напасть', 'ru', 'violence', 'high', false),
    ('оружие', 'ru', 'violence', 'medium', false),
    ('убийство', 'ru', 'violence', 'high', false),
    ('угроза', 'ru', 'violence', 'medium', false),
    ('взорвать', 'ru', 'violence', 'high', false);

COMMIT;
-- ============================================
-- 014: Update review defaults and add notification
-- delivery status tracking (FR-026)
-- ============================================

BEGIN;

-- Update deanonymization access hours default to 72 (spec clarification)
ALTER TABLE review_configuration
    ALTER COLUMN deanonymization_access_hours SET DEFAULT 72;

UPDATE review_configuration
    SET deanonymization_access_hours = 72
    WHERE id = 1 AND deanonymization_access_hours = 24;

-- Add notification delivery status to risk_flags (FR-026)
-- Tracks whether high-risk flag notifications were successfully delivered
ALTER TABLE risk_flags
    ADD COLUMN IF NOT EXISTS notification_delivery_status VARCHAR(10)
    DEFAULT 'pending'
    CHECK (notification_delivery_status IN ('delivered', 'pending', 'failed'));

COMMIT;
-- 015_add_tagging_system.sql
-- Adds tag definitions, user-tag assignments, session-tag assignments,
-- session exclusion records, and min message threshold configuration.
BEGIN;

-- 1. Tag definitions table (shared namespace)
CREATE TABLE IF NOT EXISTS tag_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    name_lower VARCHAR(100) NOT NULL GENERATED ALWAYS AS (LOWER(name)) STORED,
    description TEXT,
    category VARCHAR(10) NOT NULL CHECK (category IN ('user', 'chat')),
    exclude_from_reviews BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_definitions_name_lower
    ON tag_definitions(name_lower);
CREATE INDEX IF NOT EXISTS idx_tag_definitions_category
    ON tag_definitions(category);
CREATE INDEX IF NOT EXISTS idx_tag_definitions_active
    ON tag_definitions(is_active) WHERE is_active = true;

-- 2. User-tag assignments
CREATE TABLE IF NOT EXISTS user_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tag_definition_id UUID NOT NULL REFERENCES tag_definitions(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_tags_user_tag
    ON user_tags(user_id, tag_definition_id);
CREATE INDEX IF NOT EXISTS idx_user_tags_user
    ON user_tags(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tags_tag
    ON user_tags(tag_definition_id);

-- 3. Session-tag assignments
CREATE TABLE IF NOT EXISTS session_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    tag_definition_id UUID NOT NULL REFERENCES tag_definitions(id) ON DELETE CASCADE,
    source VARCHAR(10) NOT NULL CHECK (source IN ('system', 'manual')),
    applied_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Compatibility path for environments that already had legacy moderation tags
-- from migration 005 (session_tags.tag_id -> tags.id, plus added_by column).
-- This block is idempotent and safely upgrades the shape expected by current services.
DO $$
BEGIN
    IF to_regclass('public.tags') IS NOT NULL THEN
        INSERT INTO tag_definitions (name, description, category, exclude_from_reviews, is_active)
        SELECT
            t.name,
            NULLIF(t.description, ''),
            'chat',
            false,
            true
        FROM tags t
        ON CONFLICT (name_lower) DO NOTHING;
    END IF;

    IF to_regclass('public.session_tags') IS NOT NULL THEN
        -- Add new FK column when migrating from legacy schema.
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'tag_id'
        ) AND NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'tag_definition_id'
        ) THEN
            ALTER TABLE session_tags ADD COLUMN tag_definition_id UUID;
        END IF;

        -- Backfill tag_definition_id from legacy tags mapping by normalized name.
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'tag_definition_id'
        ) AND EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'tag_id'
        ) AND to_regclass('public.tags') IS NOT NULL THEN
            UPDATE session_tags st
            SET tag_definition_id = td.id
            FROM tags t
            JOIN tag_definitions td ON td.name_lower = LOWER(t.name)
            WHERE st.tag_id = t.id
              AND st.tag_definition_id IS NULL;
        END IF;

        -- Legacy column rename.
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'added_by'
        ) AND NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'applied_by'
        ) THEN
            ALTER TABLE session_tags RENAME COLUMN added_by TO applied_by;
        END IF;

        -- Ensure newer columns exist.
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'applied_by'
        ) THEN
            ALTER TABLE session_tags ADD COLUMN applied_by UUID REFERENCES users(id);
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'source'
        ) THEN
            ALTER TABLE session_tags ADD COLUMN source VARCHAR(10) NOT NULL DEFAULT 'manual';
        END IF;

        -- Keep source values compatible with current check constraint.
        UPDATE session_tags
        SET source = 'manual'
        WHERE source IS NULL OR source NOT IN ('system', 'manual');

        -- Add surrogate id where legacy composite PK exists.
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'id'
        ) THEN
            ALTER TABLE session_tags ADD COLUMN id UUID DEFAULT gen_random_uuid();
        END IF;

        UPDATE session_tags
        SET id = gen_random_uuid()
        WHERE id IS NULL;

        -- If no unresolved legacy mappings remain, enforce NOT NULL.
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'tag_definition_id'
        ) AND NOT EXISTS (
            SELECT 1 FROM session_tags WHERE tag_definition_id IS NULL
        ) THEN
            ALTER TABLE session_tags ALTER COLUMN tag_definition_id SET NOT NULL;
        END IF;

        -- Ensure FK exists for tag_definition_id.
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'session_tags' AND column_name = 'tag_definition_id'
        ) AND NOT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conrelid = 'session_tags'::regclass
              AND conname = 'session_tags_tag_definition_id_fkey'
        ) THEN
            ALTER TABLE session_tags
                ADD CONSTRAINT session_tags_tag_definition_id_fkey
                FOREIGN KEY (tag_definition_id) REFERENCES tag_definitions(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_session_tags_session_tag
    ON session_tags(session_id, tag_definition_id);
CREATE INDEX IF NOT EXISTS idx_session_tags_session
    ON session_tags(session_id);
CREATE INDEX IF NOT EXISTS idx_session_tags_tag
    ON session_tags(tag_definition_id);

-- 4. Session exclusion records
CREATE TABLE IF NOT EXISTS session_exclusions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    reason VARCHAR(100) NOT NULL,
    reason_source VARCHAR(10) NOT NULL CHECK (reason_source IN ('user_tag', 'chat_tag')),
    tag_definition_id UUID REFERENCES tag_definitions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_exclusions_session
    ON session_exclusions(session_id);

-- 5. Extend review_configuration with min message threshold
ALTER TABLE review_configuration
    ADD COLUMN IF NOT EXISTS min_message_threshold SMALLINT NOT NULL DEFAULT 4;

-- 6. Seed predefined tags
INSERT INTO tag_definitions (name, description, category, exclude_from_reviews, is_active)
VALUES
    ('functional QA', 'Tag for test/QA user accounts whose sessions should be excluded from the review queue', 'user', true, true),
    ('short', 'Auto-applied to chat sessions with fewer messages than the configured minimum threshold', 'chat', true, true)
ON CONFLICT (name_lower) DO NOTHING;

COMMIT;
-- 016_add_supervisor_role.sql
-- Adds 'supervisor' to the user role constraint.
BEGIN;

-- The role column uses a CHECK constraint, not a native ENUM.
-- Drop and recreate the constraint to include the new value.
DO $$
BEGIN
    -- Find and drop existing role check constraint
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'users'::regclass
          AND contype = 'c'
          AND pg_get_constraintdef(oid) ILIKE '%role%'
    ) THEN
        EXECUTE (
            SELECT 'ALTER TABLE users DROP CONSTRAINT ' || quote_ident(conname)
            FROM pg_constraint
            WHERE conrelid = 'users'::regclass
              AND contype = 'c'
              AND pg_get_constraintdef(oid) ILIKE '%role%'
            LIMIT 1
        );
    END IF;
END $$;

ALTER TABLE users
    ADD CONSTRAINT users_role_check
    CHECK (role IN ('user', 'qa_specialist', 'researcher', 'supervisor', 'moderator', 'group_admin', 'owner'));

COMMIT;
-- 017_add_grade_descriptions.sql
-- Creates grade_descriptions table with seed data for score levels 1-10.
BEGIN;

CREATE TABLE IF NOT EXISTS grade_descriptions (
    score_level INT PRIMARY KEY CHECK (score_level >= 1 AND score_level <= 10),
    description TEXT NOT NULL,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO grade_descriptions (score_level, description) VALUES
    (10, 'Outstanding — The AI response is exceptionally helpful, accurate, empathetic, and safe. No improvements needed.'),
    (9,  'Excellent — The response is highly effective with only negligible room for improvement.'),
    (8,  'Very Good — The response is strong overall with minor areas that could be slightly better.'),
    (7,  'Good — The response is solid and appropriate, meeting expectations with some room for polish.'),
    (6,  'Adequate — The response is acceptable but has noticeable gaps in quality or sensitivity.'),
    (5,  'Below Average — The response has significant weaknesses that reduce its helpfulness or appropriateness.'),
    (4,  'Poor — The response fails to adequately address the user''s needs or demonstrates notable issues.'),
    (3,  'Very Poor — The response is largely unhelpful, insensitive, or contains meaningful errors.'),
    (2,  'Harmful — The response may cause distress or contains dangerous/misleading content.'),
    (1,  'Unsafe — The response actively endangers the user''s wellbeing or violates critical safety guidelines.')
ON CONFLICT (score_level) DO NOTHING;

COMMIT;
-- 018_add_group_review_config.sql
-- Per-group review configuration overrides.
BEGIN;

CREATE TABLE IF NOT EXISTS group_review_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL UNIQUE REFERENCES groups(id) ON DELETE CASCADE,
    reviewer_count_override INT CHECK (reviewer_count_override IS NULL OR reviewer_count_override >= 1),
    supervision_policy VARCHAR(20) CHECK (supervision_policy IS NULL OR supervision_policy IN ('all', 'sampled', 'none')),
    supervision_sample_percentage INT CHECK (supervision_sample_percentage IS NULL OR (supervision_sample_percentage >= 1 AND supervision_sample_percentage <= 100)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_group_review_config_group
    ON group_review_config(group_id);

-- Auto-update updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'set_group_review_config_updated_at'
    ) THEN
        CREATE TRIGGER set_group_review_config_updated_at
            BEFORE UPDATE ON group_review_config
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

COMMIT;
-- 019_extend_review_config_supervision.sql
-- Adds supervision_policy and supervision_sample_percentage to review_configuration.
BEGIN;

ALTER TABLE review_configuration
    ADD COLUMN IF NOT EXISTS supervision_policy VARCHAR(20) NOT NULL DEFAULT 'none'
        CHECK (supervision_policy IN ('all', 'sampled', 'none'));

ALTER TABLE review_configuration
    ADD COLUMN IF NOT EXISTS supervision_sample_percentage INT NOT NULL DEFAULT 100
        CHECK (supervision_sample_percentage >= 1 AND supervision_sample_percentage <= 100);

COMMIT;
-- 020_extend_session_reviews_supervision.sql
-- Adds supervision_status and supervision_required to session_reviews.
BEGIN;

ALTER TABLE session_reviews
    ADD COLUMN IF NOT EXISTS supervision_status VARCHAR(30)
        CHECK (supervision_status IS NULL OR supervision_status IN (
            'pending_supervision', 'approved', 'disapproved', 'revision_requested', 'not_required'
        ));

ALTER TABLE session_reviews
    ADD COLUMN IF NOT EXISTS supervision_required BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_session_reviews_supervision_status
    ON session_reviews(supervision_status)
    WHERE supervision_status = 'pending_supervision';

COMMIT;
-- 021_add_supervisor_reviews.sql
-- Creates supervisor_reviews table for second-level review decisions.
BEGIN;

CREATE TABLE IF NOT EXISTS supervisor_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_review_id UUID NOT NULL REFERENCES session_reviews(id) ON DELETE CASCADE,
    supervisor_id UUID NOT NULL REFERENCES users(id),
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('approved', 'disapproved')),
    comments TEXT NOT NULL CHECK (LENGTH(comments) >= 1),
    return_to_reviewer BOOLEAN NOT NULL DEFAULT false,
    revision_iteration INT NOT NULL DEFAULT 1 CHECK (revision_iteration >= 1 AND revision_iteration <= 3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_supervisor_review_iteration UNIQUE (session_review_id, revision_iteration)
);

CREATE INDEX IF NOT EXISTS idx_supervisor_reviews_session_review_id
    ON supervisor_reviews(session_review_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_reviews_supervisor_id
    ON supervisor_reviews(supervisor_id);

COMMIT;
-- Add Google OAuth identity column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255) UNIQUE;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_sub ON users(google_sub) WHERE google_sub IS NOT NULL;

-- Add OTP disable setting for workbench
ALTER TABLE settings ADD COLUMN IF NOT EXISTS otp_login_disabled_workbench BOOLEAN NOT NULL DEFAULT FALSE;
-- ============================================
-- Backfill: group session visibility
-- ============================================
-- Fixes users and sessions that were affected by addUserToGroup(),
-- createAndAddUserToGroup(), and approveGroupRequest() not setting
-- users.active_group_id when creating/activating group memberships.

-- Step 1: Set active_group_id for users who have active memberships
-- but NULL active_group_id and NULL group_id.
-- Uses the earliest approved membership to pick a deterministic group.
UPDATE users u
SET active_group_id = (
  SELECT gm.group_id
  FROM group_memberships gm
  WHERE gm.user_id = u.id AND gm.status = 'active'
  ORDER BY gm.approved_at ASC NULLS LAST
  LIMIT 1
)
WHERE u.active_group_id IS NULL
  AND u.group_id IS NULL
  AND EXISTS (
    SELECT 1 FROM group_memberships gm
    WHERE gm.user_id = u.id AND gm.status = 'active'
  );

-- Step 2: Backfill sessions.group_id using group_memberships
-- for sessions where group_id is NULL but user has an active membership.
UPDATE sessions s
SET group_id = (
  SELECT gm.group_id
  FROM group_memberships gm
  WHERE gm.user_id = s.user_id AND gm.status = 'active'
  ORDER BY gm.approved_at ASC NULLS LAST
  LIMIT 1
)
WHERE s.group_id IS NULL
  AND s.user_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM group_memberships gm
    WHERE gm.user_id = s.user_id AND gm.status = 'active'
  );
-- Migration 024: Create Survey Module tables
-- Feature: MHG-SURV-001 (Workbench Survey Module)
-- Rollback: DROP TABLE survey_responses; DROP TABLE survey_instances; DROP TABLE survey_schemas;

-- SurveySchema
CREATE TABLE survey_schemas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           VARCHAR(200)  NOT NULL,
  description     TEXT,
  status          VARCHAR(20)   NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','published','archived')),
  questions       JSONB         NOT NULL DEFAULT '[]',
  cloned_from_id  UUID          REFERENCES survey_schemas(id) ON DELETE SET NULL,
  created_by      UUID          NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  published_at    TIMESTAMPTZ,
  archived_at     TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- SurveyInstance
CREATE TABLE survey_instances (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schema_id        UUID          NOT NULL REFERENCES survey_schemas(id),
  schema_snapshot  JSONB         NOT NULL,
  title            VARCHAR(200)  NOT NULL,
  status           VARCHAR(20)   NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','active','expired','closed')),
  priority         INTEGER       NOT NULL DEFAULT 0,
  group_ids        UUID[]        NOT NULL,
  start_date       TIMESTAMPTZ   NOT NULL,
  expiration_date  TIMESTAMPTZ   NOT NULL,
  created_by       UUID          NOT NULL REFERENCES users(id),
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  closed_at        TIMESTAMPTZ,
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CONSTRAINT expiry_after_start CHECK (expiration_date > start_date)
);

-- SurveyResponse
CREATE TABLE survey_responses (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instance_id      UUID          NOT NULL REFERENCES survey_instances(id),
  pseudonymous_id  UUID          NOT NULL,
  answers          JSONB         NOT NULL DEFAULT '[]',
  started_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  completed_at     TIMESTAMPTZ,
  is_complete      BOOLEAN       NOT NULL DEFAULT false,
  UNIQUE (instance_id, pseudonymous_id)
);

-- Indexes
CREATE INDEX idx_survey_instances_status     ON survey_instances(status);
CREATE INDEX idx_survey_instances_group_ids  ON survey_instances USING GIN(group_ids);
CREATE INDEX idx_survey_responses_instance   ON survey_responses(instance_id);
CREATE INDEX idx_survey_responses_pseudo     ON survey_responses(pseudonymous_id);
-- Migration 025: Extend Survey tables for invalidation + memory + group context
-- Feature: MHG-SURV-001 (Workbench Survey Module)
-- Rollback (manual): DROP INDEXes created here; then ALTER TABLE ... DROP COLUMN ...

-- 1) SurveyInstance: add add_to_memory toggle
ALTER TABLE survey_instances
  ADD COLUMN add_to_memory BOOLEAN NOT NULL DEFAULT false;

-- 2) SurveyResponse: add group context + invalidation markers
ALTER TABLE survey_responses
  ADD COLUMN group_id UUID,
  ADD COLUMN invalidated_at TIMESTAMPTZ,
  ADD COLUMN invalidated_by UUID REFERENCES users(id),
  ADD COLUMN invalidation_reason TEXT;

-- Best-effort backfill for existing rows:
-- If an instance targets exactly one group, we can deterministically set group_id.
UPDATE survey_responses sr
SET group_id = si.group_ids[1]
FROM survey_instances si
WHERE si.id = sr.instance_id
  AND sr.group_id IS NULL
  AND array_length(si.group_ids, 1) = 1;

-- 3) Indexes supporting gate-check + invalidation queries
CREATE INDEX idx_survey_responses_instance_group
  ON survey_responses(instance_id, group_id);

-- Fast "is the gate satisfied?" lookups:
CREATE INDEX idx_survey_responses_valid_gate
  ON survey_responses(instance_id, pseudonymous_id)
  WHERE is_complete = true AND invalidated_at IS NULL;

-- Migration 026: Survey Module Enhancements
-- Feature: 019-survey-question-enhancements
-- Rollback: DROP TABLE group_survey_order; ALTER TABLE survey_instances DROP COLUMN public_header, DROP COLUMN show_review, ADD COLUMN priority INTEGER NOT NULL DEFAULT 0; ALTER TABLE group_invite_codes DROP COLUMN requires_approval;

-- 1) New table: per-group survey ordering (replaces priority field)
CREATE TABLE IF NOT EXISTS group_survey_order (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id       UUID NOT NULL,
  instance_id    UUID NOT NULL REFERENCES survey_instances(id) ON DELETE CASCADE,
  display_order  INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (group_id, instance_id)
);
CREATE INDEX IF NOT EXISTS idx_group_survey_order_group ON group_survey_order(group_id);

-- 2) Seed group_survey_order from existing instances using priority+start_date ordering.
-- Each instance may target multiple groups (group_ids array); create one row per group.
INSERT INTO group_survey_order (group_id, instance_id, display_order)
SELECT
  g AS group_id,
  si.id AS instance_id,
  ROW_NUMBER() OVER (PARTITION BY g ORDER BY si.start_date ASC)::INTEGER AS display_order
FROM survey_instances si,
     LATERAL unnest(si.group_ids) AS g
ON CONFLICT (group_id, instance_id) DO NOTHING;

-- 3) Instance enhancements: custom header + optional review step
ALTER TABLE survey_instances
  ADD COLUMN IF NOT EXISTS public_header VARCHAR(300),
  ADD COLUMN IF NOT EXISTS show_review BOOLEAN NOT NULL DEFAULT true;

-- 4) Remove priority field (replaced by group_survey_order)
ALTER TABLE survey_instances
  DROP COLUMN IF EXISTS priority;

-- 5) Invitation code: per-code approval control
ALTER TABLE group_invite_codes
  ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN NOT NULL DEFAULT true;
-- Migration 027: Add requires_approval to group_invite_codes
-- Fixes 026 partial migration where invitation_codes was the wrong table name
ALTER TABLE group_invite_codes
  ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN NOT NULL DEFAULT true;
-- Migration 028: Supervisor-only message archival + default supervision policy = 'all'
--
-- 1. Change default supervision policy from 'none' to 'all' so every submitted
--    review is automatically routed to the supervisor queue.
-- 2. Add messages_archived_at / messages_archived_by to sessions so supervisors
--    can permanently archive message content after supervision.

BEGIN;

-- ── 1. Default supervision policy ──────────────────────────────────────────

-- Update the column default for new rows
ALTER TABLE review_configuration
  ALTER COLUMN supervision_policy SET DEFAULT 'all';

-- Migrate existing rows that use the old default
UPDATE review_configuration
  SET supervision_policy = 'all'
  WHERE supervision_policy = 'none';

-- ── 2. Message archival columns on sessions ─────────────────────────────────

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS messages_archived_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS messages_archived_by UUID REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON COLUMN sessions.messages_archived_at IS
  'When a supervisor archived message content for this session (null = not archived)';
COMMENT ON COLUMN sessions.messages_archived_by IS
  'Supervisor who archived the message content';

COMMIT;
-- Migration 029: Ensure the singleton settings row exists.
--
-- schema.sql creates the settings table but never inserts a default row.
-- If no row exists, PATCH /api/admin/settings returns 0 rows, causing a
-- 500 when the service tries to read result.rows[0].
--
-- ON CONFLICT (id) DO NOTHING is safe for existing rows.

INSERT INTO settings (id, guest_mode_enabled, approval_cooloff_days, otp_login_disabled_workbench)
VALUES (1, false, 7, false)
ON CONFLICT (id) DO NOTHING;
-- Migration 030: Remove session_review expiration concept.
--
-- The assignment expiration mechanism (expires_at column, 'expired' status) was
-- never scheduled as a background job, so reviews never actually expired in practice.
-- The expires_at timestamp was still surfaced to the frontend, causing confusing
-- "Overdue" badges on old stuck assignments.
--
-- This migration:
--   1. Cleans up stuck pending/in_progress assignments older than 30 days,
--      resetting the parent session back to pending_review when no other
--      active review exists.
--   2. Removes the 'expired' status and expires_at column from session_reviews.

BEGIN;

-- Step 1: Reset sessions that are stuck in 'in_review' because of orphaned
-- pending assignments that are more than 30 days old.
UPDATE sessions
SET review_status = 'pending_review'
WHERE review_status = 'in_review'
  AND review_count = 0
  AND EXISTS (
    SELECT 1 FROM session_reviews sr
    WHERE sr.session_id = sessions.id
      AND sr.status IN ('pending', 'in_progress')
      AND sr.updated_at < NOW() - INTERVAL '30 days'
  )
  AND NOT EXISTS (
    SELECT 1 FROM session_reviews sr
    WHERE sr.session_id = sessions.id
      AND sr.status = 'completed'
  );

-- Step 2: Delete stale pending/in_progress assignments older than 30 days.
DELETE FROM session_reviews
WHERE status IN ('pending', 'in_progress')
  AND updated_at < NOW() - INTERVAL '30 days';

-- Step 3: Delete any rows with 'expired' status (from manual calls if any).
DELETE FROM session_reviews WHERE status = 'expired';

-- Step 4: Drop the partial index that referenced expires_at.
DROP INDEX IF EXISTS idx_session_reviews_expires_at_active;

-- Step 5: Remove the expires_at column.
ALTER TABLE session_reviews DROP COLUMN IF EXISTS expires_at;

-- Step 6: Update the status CHECK constraint to remove 'expired'.
ALTER TABLE session_reviews
  DROP CONSTRAINT IF EXISTS session_reviews_status_check;

ALTER TABLE session_reviews
  ADD CONSTRAINT session_reviews_status_check
  CHECK (status IN ('pending', 'in_progress', 'completed'));

COMMIT;
-- Migration 031: Relax criteria_feedback.feedback_text minimum-length constraint.
--
-- The review system previously required reviewers to type at least 10 characters
-- of free-form text for each selected criterion (enforced at DB, backend, and
-- frontend levels). The UX was changed to a checkbox-style interaction where
-- selecting a criterion without additional text stores the criterion key itself
-- as a sentinel (e.g. feedback_text = 'relevance'). The shortest criterion key
-- is 'safety' / 'ethics' (6 chars) and 'empathy' / 'clarity' (7 chars), all
-- below the old 10-char floor.
--
-- Drop the LENGTH check; the NOT NULL constraint is retained so empty strings
-- are still rejected. Frontend and backend application-level validation continue
-- to enforce the checkbox-requires-at-least-one rule.

ALTER TABLE criteria_feedback
  DROP CONSTRAINT IF EXISTS criteria_feedback_feedback_text_check;
-- 032_seed_tester_tag_definition.sql
-- Seeds the missing 'tester' tag definition row into tag_definitions.
-- Migration 015_add_tagging_system.sql created the table and seeded
-- 'functional QA' and 'short' but did not include 'tester'.
-- Because 015 has already been applied on all environments, this
-- separate migration inserts the row idempotently.
BEGIN;

INSERT INTO tag_definitions (name, description, category, exclude_from_reviews, is_active)
VALUES (
  'tester',
  'Grants tester-only access to internal diagnostic UI features such as RAG detail panels. Assigned by Admin, Supervisor, or Owner roles.',
  'user',
  false,
  true
)
ON CONFLICT (name_lower) DO NOTHING;

COMMIT;
-- Move public_header from survey_instances to survey_schemas.
-- Existing instance public_header values are intentionally discarded as the
-- field is being repurposed at the schema level going forward.

ALTER TABLE survey_schemas ADD COLUMN IF NOT EXISTS public_header TEXT;
ALTER TABLE survey_instances DROP COLUMN IF EXISTS public_header;
-- ============================================
-- 034: Pseudonymous user identity (FR-001)
-- ============================================
-- Adds pseudonymous_user_id (UUID v4), per-user salt, and soft-delete
-- support to the users table. These columns support the privacy
-- architecture: health data tables reference pseudonymous_user_id only,
-- never id/email/display_name.
--
-- PREREQUISITE: Run data migration 030-001-assign-pseudonymous-ids.ts
-- BEFORE applying this migration. That script pre-populates the column
-- for all existing rows so the NOT NULL constraint lands cleanly.
--
-- PII columns (email, display_name) are retained in this migration to
-- preserve existing application functionality. They will be removed
-- in a coordinated subsequent migration once all downstream consumers
-- are updated to reference pseudonymous_user_id.
-- ============================================

-- Add columns if the data migration has not already done so
-- anonymised_at: set by GDPR anonymisation cascade (not deleted_at — health data is retained)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS pseudonymous_user_id UUID UNIQUE,
  ADD COLUMN IF NOT EXISTS pseudonymous_salt BYTEA,
  ADD COLUMN IF NOT EXISTS anonymised_at TIMESTAMP WITH TIME ZONE;

-- For any users that somehow still lack a pseudonymous_user_id
-- (e.g. inserted after data migration ran but before this migration),
-- generate one now so the NOT NULL constraint below succeeds.
UPDATE users
  SET pseudonymous_user_id = gen_random_uuid(),
      pseudonymous_salt = gen_random_bytes(32)
WHERE pseudonymous_user_id IS NULL;

-- Now make pseudonymous_user_id NOT NULL
ALTER TABLE users
  ALTER COLUMN pseudonymous_user_id SET NOT NULL,
  ALTER COLUMN pseudonymous_salt SET NOT NULL;

-- Ensure new inserts always get a pseudonymous_user_id
ALTER TABLE users
  ALTER COLUMN pseudonymous_user_id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN pseudonymous_salt SET DEFAULT gen_random_bytes(32);

-- Index for FK lookups from health data tables
CREATE INDEX IF NOT EXISTS idx_users_pseudonymous_user_id
  ON users(pseudonymous_user_id);

-- Index for anonymisation status filtering
CREATE INDEX IF NOT EXISTS idx_users_anonymised_at
  ON users(anonymised_at)
  WHERE anonymised_at IS NOT NULL;

COMMENT ON COLUMN users.pseudonymous_user_id IS
  'UUID v4 pseudonymous identity. Used in all health data tables (assessments, analytics, annotations). No PII.';
COMMENT ON COLUMN users.pseudonymous_salt IS
  'Random 32-byte salt used by auth service for credential hashing. Never exposed in API responses.';
COMMENT ON COLUMN users.anonymised_at IS
  'Set by GDPR anonymisation cascade (FR-003). NULL = active user. When set, the identity map record has been deleted and this pseudonymous_user_id is permanently unresolvable — health data linked to it is legally anonymous.';
-- Migration 034: Review Queue Safety Prioritisation (spec 032)
-- Adds safety_priority to sessions, extends risk_flags, creates safety_flag_audit_events.

-- 1. Add safety_priority to sessions
ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS safety_priority VARCHAR(16) NOT NULL DEFAULT 'normal'
  CHECK (safety_priority IN ('normal', 'elevated'));

CREATE INDEX IF NOT EXISTS idx_sessions_safety_priority
  ON sessions (safety_priority)
  WHERE safety_priority = 'elevated';

-- 2. Extend risk_flags with AI filter metadata
ALTER TABLE risk_flags
  ADD COLUMN IF NOT EXISTS confidence DECIMAL(4,3),
  ADD COLUMN IF NOT EXISTS flag_source VARCHAR(32) NOT NULL DEFAULT 'manual'
  CHECK (flag_source IN ('manual', 'ai_filter_high', 'ai_filter_low'));

-- 3. Create append-only audit log for safety flag lifecycle events
CREATE TABLE IF NOT EXISTS safety_flag_audit_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flag_id     UUID NOT NULL REFERENCES risk_flags(id),
  event_type  VARCHAR(32) NOT NULL
    CHECK (event_type IN ('created', 'resolved', 'escalated', 'false_positive', 'reopened')),
  actor_id    UUID REFERENCES users(id),  -- NULL for system-originated events
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_safety_flag_audit_flag_id
  ON safety_flag_audit_events (flag_id);

CREATE INDEX IF NOT EXISTS idx_safety_flag_audit_created_at
  ON safety_flag_audit_events (created_at DESC);
-- ============================================
-- 035: User identity map schema documentation (FR-002, T018)
-- ============================================
-- The user_identity_map TABLE resides on the SEPARATE Cloud SQL instance
-- (chat-identity-map-dev / chat-identity-map-prod), not on this database.
-- It is created by the auth service at startup using the schema below.
--
-- This migration is a no-op on the main database. It documents the remote
-- schema for reference and creates only the gdpr_audit_log table (which
-- records identity map events) on the main database.
-- ============================================

-- ── gdpr_audit_log ────────────────────────────────────────────────────────
-- Stores audit events for GDPR operations: erasures, consent revocations,
-- PII filter events, identity map access attempts, CSV exports (FR-003, FR-028).

CREATE TABLE IF NOT EXISTS gdpr_audit_log (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    actor VARCHAR(255) NOT NULL,
    -- One-way SHA-256 hash of pseudonymous_user_id; not reversible
    pseudonymous_user_id_hash VARCHAR(64),
    details JSONB NOT NULL DEFAULT '{}',
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    outcome VARCHAR(20) NOT NULL DEFAULT 'success'
        CHECK (outcome IN ('success', 'failure', 'pending'))
);

CREATE INDEX IF NOT EXISTS idx_gdpr_audit_log_event_type
    ON gdpr_audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_gdpr_audit_log_occurred_at
    ON gdpr_audit_log(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_gdpr_audit_log_pseudonymous_hash
    ON gdpr_audit_log(pseudonymous_user_id_hash)
    WHERE pseudonymous_user_id_hash IS NOT NULL;

COMMENT ON TABLE gdpr_audit_log IS
    'Audit log for all GDPR-relevant events (FR-006, FR-028). 3-year retention via Cloud Logging sink.';
COMMENT ON COLUMN gdpr_audit_log.pseudonymous_user_id_hash IS
    'SHA-256 of pseudonymous_user_id — stored for audit traceability without re-identifying the user.';

-- ── erasure_jobs ──────────────────────────────────────────────────────────
-- Tracks async right-to-erasure jobs. Target SLA: 24h; legal max 30 days (FR-003).

CREATE TABLE IF NOT EXISTS erasure_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pseudonymous_user_id UUID NOT NULL REFERENCES users(pseudonymous_user_id) ON DELETE SET NULL DEFERRABLE,
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    requested_by_actor_id UUID,
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_progress', 'completed', 'failed')),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    failure_reason TEXT,
    duration_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_erasure_jobs_status
    ON erasure_jobs(status)
    WHERE status IN ('pending', 'in_progress');
CREATE INDEX IF NOT EXISTS idx_erasure_jobs_requested_at
    ON erasure_jobs(requested_at DESC);

COMMENT ON TABLE erasure_jobs IS
    'GDPR right-to-erasure async jobs (FR-003). SLA: complete within 24h (legal max 30 days).';

-- ── Remote schema reference (identity map instance) ──────────────────────
-- The following CREATE TABLE would be run on the chat-identity-map-dev instance
-- by the auth service on first boot. Documented here for audit trail.
--
-- CREATE TABLE IF NOT EXISTS user_identity_map (
--     identity_mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--     credential_hash     VARCHAR(128) NOT NULL UNIQUE,
--     pseudonymous_user_id UUID NOT NULL,
--     credential_type     VARCHAR(30) NOT NULL CHECK (credential_type IN ('otp_phone_hash', 'device_uuid')),
--     created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
--     upgraded_at         TIMESTAMP WITH TIME ZONE,
--     is_active           BOOLEAN NOT NULL DEFAULT TRUE
-- );
-- CREATE INDEX IF NOT EXISTS idx_identity_map_credential_hash ON user_identity_map(credential_hash);
-- CREATE INDEX IF NOT EXISTS idx_identity_map_pseudonymous_user_id ON user_identity_map(pseudonymous_user_id);
-- ============================================
-- 036: Consent records (FR-008)
-- ============================================
-- Append-only consent history. Each version change or category change
-- creates a new record — previous records are never modified.
--
-- Category semantics:
--   1 = Basic session service
--   2 = Intake data processing
--   3 = Clinical assessment data processing
-- ============================================

CREATE TABLE IF NOT EXISTS consent_records (
  consent_record_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  pseudonymous_user_id UUID        NOT NULL
                                   REFERENCES users(pseudonymous_user_id)
                                   ON DELETE RESTRICT,
  consent_version      TEXT        NOT NULL,
  accepted_categories  JSONB       NOT NULL,  -- e.g. [1, 2, 3]
  method               TEXT        NOT NULL
                                   CHECK (method IN ('explicit_tap', 're_consent_prompt')),
  consented_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at           TIMESTAMPTZ
);

-- Fast lookups by user (most common query: "what did this user consent to?")
CREATE INDEX IF NOT EXISTS idx_consent_records_user
  ON consent_records(pseudonymous_user_id, consented_at DESC);

-- Unique latest-version lookup per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_consent_records_user_version
  ON consent_records(pseudonymous_user_id, consent_version)
  WHERE revoked_at IS NULL;

COMMENT ON TABLE consent_records IS
  'Append-only consent history (FR-008). One record per consent event. Never updated — revocation sets revoked_at on the applicable record.';

COMMENT ON COLUMN consent_records.accepted_categories IS
  'JSONB array of accepted category codes, e.g. [1, 2, 3]. Partial consent allowed (e.g. [1, 2] without 3).';

COMMENT ON COLUMN consent_records.method IS
  'How consent was obtained: explicit_tap (initial) or re_consent_prompt (version upgrade).';
-- ============================================
-- 037: Cohorts & cohort memberships (FR-011, FR-012, FR-027)
-- ============================================
-- cohorts             — org-level groupings with invite codes
-- cohort_memberships  — pseudonymous user ↔ cohort join records
-- supervisor_cohort_assignments — RBAC: which cohorts a supervisor can see
-- ============================================

-- ----------------------------------------
-- cohorts
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS cohorts (
  cohort_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id UUID        NOT NULL,
  region          TEXT        NOT NULL,
  role_category   TEXT,
  invite_code     TEXT        NOT NULL UNIQUE
                              CHECK (invite_code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ,                      -- NULL = never expires
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_cohorts_invite_code
  ON cohorts(invite_code)
  WHERE is_active = TRUE;

COMMENT ON TABLE cohorts IS
  'Organisational cohorts. invite_code must be 8-char uppercase alphanumeric, excluding O/0/I/1 (CHECK constraint). Analytics unlocked when membership count >= 25 (FR-012).';

COMMENT ON COLUMN cohorts.invite_code IS
  'Regex: ^[A-HJ-NP-Z2-9]{8}$ — uppercase letters A-H, J-N, P-Z and digits 2-9 (excludes O/0/I/1 for readability).';

-- ----------------------------------------
-- cohort_memberships
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS cohort_memberships (
  membership_id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  pseudonymous_user_id UUID        NOT NULL
                                   REFERENCES users(pseudonymous_user_id)
                                   ON DELETE RESTRICT,
  cohort_id            UUID        NOT NULL
                                   REFERENCES cohorts(cohort_id)
                                   ON DELETE RESTRICT,
  joined_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (pseudonymous_user_id, cohort_id)
);

CREATE INDEX IF NOT EXISTS idx_cohort_memberships_cohort
  ON cohort_memberships(cohort_id);

CREATE INDEX IF NOT EXISTS idx_cohort_memberships_user
  ON cohort_memberships(pseudonymous_user_id);

COMMENT ON TABLE cohort_memberships IS
  'Pseudonymous user membership in a cohort (FR-011). No PII. Analytics cohort guard checks COUNT(*) >= 25 before unlocking workbench views.';

-- ----------------------------------------
-- supervisor_cohort_assignments
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS supervisor_cohort_assignments (
  assignment_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_user_id UUID       NOT NULL
                                REFERENCES users(pseudonymous_user_id)
                                ON DELETE RESTRICT,
  cohort_id         UUID        NOT NULL
                                REFERENCES cohorts(cohort_id)
                                ON DELETE RESTRICT,
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by       UUID        NOT NULL
                                REFERENCES users(pseudonymous_user_id)
                                ON DELETE RESTRICT,
  UNIQUE (supervisor_user_id, cohort_id)
);

CREATE INDEX IF NOT EXISTS idx_supervisor_cohort_supervisor
  ON supervisor_cohort_assignments(supervisor_user_id);

COMMENT ON TABLE supervisor_cohort_assignments IS
  'RBAC: maps a supervisor to the cohorts they are permitted to view (FR-027). All supervisor analytics queries add WHERE cohort_id IN (SELECT cohort_id FROM supervisor_cohort_assignments WHERE supervisor_user_id = $current_user).';
-- ============================================
-- 038: Clinical assessment data schema (FR-015, FR-018)
-- ============================================
-- assessment_sessions  — one record per administered instrument
-- assessment_items     — individual item responses (append-only)
-- assessment_scores    — computed total score + severity band (append-only)
--
-- Append-only enforcement: PL/pgSQL trigger blocks UPDATE/DELETE on all
-- three tables. The GDPR erasure cascade is the sole exception — it
-- operates via a separate transaction that runs as the erasure SA role,
-- which bypasses the trigger (trigger checks current_setting).
-- ============================================

-- ----------------------------------------
-- assessment_sessions
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS assessment_sessions (
  assessment_session_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  pseudonymous_user_id  UUID        REFERENCES users(pseudonymous_user_id) ON DELETE RESTRICT,
  instrument_id         UUID        NOT NULL,
  session_id            UUID,                          -- FK to chat sessions (nullable)
  administered_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at          TIMESTAMPTZ,
  status                TEXT        NOT NULL DEFAULT 'in_progress'
                                    CHECK (status IN ('in_progress', 'completed', 'abandoned'))
);

CREATE INDEX IF NOT EXISTS idx_assessment_sessions_user
  ON assessment_sessions(pseudonymous_user_id, administered_at DESC)
  WHERE pseudonymous_user_id IS NOT NULL;

-- ----------------------------------------
-- assessment_items
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS assessment_items (
  item_response_id      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_session_id UUID        NOT NULL
                                    REFERENCES assessment_sessions(assessment_session_id)
                                    ON DELETE RESTRICT,
  item_index            INTEGER     NOT NULL CHECK (item_index >= 0),
  item_key              TEXT        NOT NULL,
  response_value        INTEGER     NOT NULL,
  responded_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (assessment_session_id, item_index)
);

-- ----------------------------------------
-- assessment_scores
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS assessment_scores (
  score_id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_session_id UUID        NOT NULL
                                    REFERENCES assessment_sessions(assessment_session_id)
                                    ON DELETE RESTRICT,
  instrument_type       TEXT        NOT NULL
                                    CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5')),
  total_score           INTEGER     NOT NULL,
  severity_band         TEXT        NOT NULL
                                    CHECK (severity_band IN ('minimal', 'mild', 'moderate', 'moderately_severe', 'severe')),
  instrument_version    TEXT        NOT NULL,
  computed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  scoring_key_hash      TEXT        NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_assessment_scores_session
  ON assessment_scores(assessment_session_id);

-- ----------------------------------------
-- Append-only trigger function
-- ----------------------------------------
-- The function checks `current_setting('app.allow_erasure_nullify', true)`.
-- Only the erasure cascade sets this to 'true' — all other callers are blocked.

CREATE OR REPLACE FUNCTION enforce_append_only()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow the GDPR erasure cascade to nullify pseudonymous_user_id on sessions
  IF TG_OP = 'UPDATE'
     AND TG_TABLE_NAME = 'assessment_sessions'
     AND current_setting('app.allow_erasure_nullify', true) = 'true'
     AND OLD.pseudonymous_user_id IS NOT NULL
     AND NEW.pseudonymous_user_id IS NULL
  THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Table % is append-only. Use GDPR erasure cascade for data removal.', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_assessment_sessions_append_only
  BEFORE UPDATE OR DELETE ON assessment_sessions
  FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_assessment_items_append_only
  BEFORE UPDATE OR DELETE ON assessment_items
  FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER trg_assessment_scores_append_only
  BEFORE UPDATE OR DELETE ON assessment_scores
  FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

COMMENT ON TABLE assessment_sessions IS
  'Append-only (FR-015). One record per administered instrument instance. pseudonymous_user_id is set to NULL by GDPR erasure cascade (row retained — data becomes anonymous).';

COMMENT ON TABLE assessment_items IS
  'Append-only (FR-015). Individual item responses. FHIR: QuestionnaireResponse.item, linkId = item_key.';

COMMENT ON TABLE assessment_scores IS
  'Append-only (FR-015, FR-018). Computed total score per instrument. FHIR: Observation with LOINC code per instrument_type.';
-- ============================================
-- 039: Score trajectories materialised view (FR-016)
-- ============================================
-- Materialised view: rolling 30-day mean, Jacobson-Truax RCI,
-- and Clinically Meaningful Improvement (CMI) flags per
-- (pseudonymous_user_id, instrument_type, administered_at) tuple.
--
-- Refreshed every 15 minutes via pg_cron CONCURRENTLY.
--
-- CMI thresholds (based on published psychometric data):
--   PHQ-9  ≥ 5 points improvement = CMI
--   GAD-7  ≥ 4 points improvement = CMI
--   PCL-5  ≥ 10 points improvement = CMI
--   WHO-5  ≥ 10 points improvement = CMI
--
-- RCI formula (Jacobson-Truax 1991):
--   SEdiff = SE_measurement × √2
--   SE_measurement = SD × √(1 - reliability)
--   RCI = (score_now - score_then) / SEdiff
--   |RCI| ≥ 1.96 = reliable change (95% CI)
--
-- Published reliability values used:
--   PHQ-9:  SD=5.4, reliability=0.89
--   GAD-7:  SD=5.3, reliability=0.92
--   PCL-5:  SD=9.8, reliability=0.94
--   WHO-5:  SD=5.4, reliability=0.84
-- ============================================

CREATE MATERIALIZED VIEW IF NOT EXISTS score_trajectories AS
  WITH instrument_params AS (
    SELECT * FROM (VALUES
      ('PHQ9',  5.4,  0.89, 5),
      ('GAD7',  5.3,  0.92, 4),
      ('PCL5',  9.8,  0.94, 10),
      ('WHO5',  5.4,  0.84, 10)
    ) AS t(instrument_type, sd, reliability, cmi_threshold)
  ),

  scores_with_prev AS (
    SELECT
      ases.pseudonymous_user_id,
      asc_.instrument_type,
      asc_.total_score,
      ases.administered_at,
      LAG(asc_.total_score) OVER (
        PARTITION BY ases.pseudonymous_user_id, asc_.instrument_type
        ORDER BY ases.administered_at
      ) AS prev_score
    FROM assessment_scores  asc_
    JOIN assessment_sessions ases
      ON ases.assessment_session_id = asc_.assessment_session_id
    WHERE ases.pseudonymous_user_id IS NOT NULL
      AND ases.status = 'completed'
  )

  SELECT
    sp.pseudonymous_user_id,
    sp.instrument_type,
    sp.total_score,
    sp.administered_at,

    -- Rolling 30-day mean
    AVG(sp.total_score) OVER (
      PARTITION BY sp.pseudonymous_user_id, sp.instrument_type
      ORDER BY sp.administered_at
      RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
    )::NUMERIC(6,2)               AS rolling_30d_mean,

    -- Jacobson-Truax RCI = (score_now - score_prev) / SEdiff
    -- SEdiff = sd * sqrt(1 - reliability) * sqrt(2)
    CASE
      WHEN sp.prev_score IS NULL THEN NULL
      ELSE ROUND(
        (sp.total_score - sp.prev_score)::NUMERIC
          / (ip.sd * SQRT(1.0 - ip.reliability) * SQRT(2.0)),
        3
      )
    END                           AS rci,

    -- CMI flag: score improved by >= cmi_threshold since last assessment
    CASE
      WHEN sp.prev_score IS NULL THEN FALSE
      ELSE (sp.prev_score - sp.total_score) >= ip.cmi_threshold
    END                           AS clinically_meaningful_improvement

  FROM scores_with_prev sp
  JOIN instrument_params ip USING (instrument_type)
WITH DATA;

-- Unique index required for CONCURRENTLY refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_score_trajectories_pk
  ON score_trajectories(pseudonymous_user_id, instrument_type, administered_at);

-- Schedule CONCURRENTLY refresh every 15 minutes via pg_cron
-- (pg_cron must be installed: CREATE EXTENSION IF NOT EXISTS pg_cron)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'refresh-score-trajectories',
      '*/15 * * * *',
      'REFRESH MATERIALIZED VIEW CONCURRENTLY score_trajectories'
    );
  END IF;
END$$;

COMMENT ON MATERIALIZED VIEW score_trajectories IS
  'FR-016: Rolling 30-day mean, Jacobson-Truax RCI, and CMI flags per (user, instrument, assessment). Refreshed every 15 min by pg_cron. Unique index required for CONCURRENTLY.';
-- ============================================
-- 040: Assessment schedule table (FR-019)
-- ============================================
-- Tracks the next scheduled assessment trigger per user per instrument.
-- Adaptive intervals: severe=14d, moderate=28d, mild/minimal=35d.
-- Cloud Tasks task name stored for cancellation on completion/deferral.
-- ============================================

CREATE TABLE IF NOT EXISTS assessment_schedule (
  schedule_id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  pseudonymous_user_id UUID        NOT NULL
                                   REFERENCES users(pseudonymous_user_id)
                                   ON DELETE RESTRICT,
  instrument_type      TEXT        NOT NULL
                                   CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5')),
  next_trigger_at      TIMESTAMPTZ NOT NULL,
  deferral_count       INTEGER     NOT NULL DEFAULT 0 CHECK (deferral_count >= 0),
  scheduler_paused     BOOLEAN     NOT NULL DEFAULT FALSE,
  last_severity_band   TEXT
                                   CHECK (last_severity_band IS NULL OR
                                          last_severity_band IN ('minimal', 'mild', 'moderate', 'moderately_severe', 'severe')),
  cloud_task_name      TEXT,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (pseudonymous_user_id, instrument_type)
);

CREATE INDEX IF NOT EXISTS idx_assessment_schedule_next_trigger
  ON assessment_schedule(next_trigger_at)
  WHERE scheduler_paused = FALSE;

COMMENT ON TABLE assessment_schedule IS
  'FR-019: Adaptive assessment scheduling. Intervals: severe/moderately_severe=14d, moderate=28d, mild/minimal=35d. cloud_task_name stored for cancellation.';

COMMENT ON COLUMN assessment_schedule.deferral_count IS
  'Number of times the user has deferred this assessment. Used by clinical algorithms to flag non-engagement.';

COMMENT ON COLUMN assessment_schedule.cloud_task_name IS
  'Cloud Tasks task name for the pending assessment reminder. Cleared and replaced on each reschedule.';
-- ============================================
-- 041: Risk thresholds config table (FR-020)
-- ============================================
-- Append-only config table managed by clinical lead.
-- New rows are added for each threshold change — old rows are retained.
-- Queries use: WHERE effective_from <= assessment.administered_at
-- to apply the correct threshold version per assessment.
--
-- threshold_value JSONB shapes:
--   absolute:      {"score": 20}
--   deterioration: {"delta": -5}              (negative = worsening)
--   item_response: {"item_index": 8, "min_value": 1}
-- ============================================

CREATE TABLE IF NOT EXISTS risk_thresholds (
  threshold_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_type  TEXT        NOT NULL
                               CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5')),
  threshold_type   TEXT        NOT NULL
                               CHECK (threshold_type IN ('absolute', 'deterioration', 'item_response')),
  threshold_value  JSONB       NOT NULL,
  tier             TEXT        NOT NULL
                               CHECK (tier IN ('critical', 'urgent', 'routine')),
  configured_by    UUID        NOT NULL
                               REFERENCES users(pseudonymous_user_id) ON DELETE RESTRICT,
  configured_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_from   TIMESTAMPTZ NOT NULL
);

-- Index for threshold lookups per assessment
CREATE INDEX IF NOT EXISTS idx_risk_thresholds_effective
  ON risk_thresholds(instrument_type, effective_from DESC);

COMMENT ON TABLE risk_thresholds IS
  'FR-020: Clinical lead configures risk thresholds. Append-only. Apply via WHERE effective_from <= assessment.administered_at.';

COMMENT ON COLUMN risk_thresholds.threshold_value IS
  'JSONB shape depends on threshold_type: absolute={"score":N}, deterioration={"delta":N}, item_response={"item_index":N,"min_value":N}.';
-- ============================================
-- 042: Risk flags update — clinical tier + deduplication (FR-021)
-- ============================================
-- Adds clinical tier column and trigger_source column to risk_flags.
-- resolved_by and resolved_at already exist (migration 013).
--
-- Tier semantics:
--   critical — always INSERT a new flag row (never deduplicate)
--   urgent   — UPDATE the existing open urgent flag if one exists; else INSERT
--   routine  — informational only
--
-- trigger_source: what generated this flag
-- ============================================

ALTER TABLE risk_flags
  ADD COLUMN IF NOT EXISTS tier TEXT
    CHECK (tier IS NULL OR tier IN ('critical', 'urgent', 'routine')),
  ADD COLUMN IF NOT EXISTS trigger_reason TEXT,
  ADD COLUMN IF NOT EXISTS trigger_source TEXT
    CHECK (trigger_source IS NULL OR
           trigger_source IN ('score_threshold', 'item_response', 'ai_filter', 'deterioration'));

-- Index for deduplication lookup (urgent tier, open status, per user)
CREATE INDEX IF NOT EXISTS idx_risk_flags_dedup
  ON risk_flags(session_id, tier, status)
  WHERE tier = 'urgent' AND status = 'open';

COMMENT ON COLUMN risk_flags.tier IS
  'FR-021: clinical tier. critical=always new row. urgent=update existing open urgent flag or insert. routine=informational.';

COMMENT ON COLUMN risk_flags.trigger_source IS
  'What generated this flag: score_threshold, item_response, ai_filter, deterioration.';
-- ============================================
-- 043: Analytics events table (FR-025)
-- ============================================
-- 8 event types, all carrying pseudonymous_user_id + cohort_id + timestamp.
-- No PII in this table.
-- ============================================

CREATE TABLE IF NOT EXISTS analytics_events (
  event_id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type           TEXT        NOT NULL
                                   CHECK (event_type IN (
                                     'session_start',
                                     'session_end',
                                     'message_sent',
                                     'assessment_completed',
                                     'assessment_abandoned',
                                     'flag_created',
                                     'flag_resolved',
                                     'review_submitted'
                                   )),
  pseudonymous_user_id UUID,       -- NULLABLE: set to NULL by GDPR erasure cascade
  cohort_id            UUID        REFERENCES cohorts(cohort_id) ON DELETE SET NULL,
  occurred_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata             JSONB       NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_type_time
  ON analytics_events(event_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_cohort
  ON analytics_events(cohort_id, occurred_at DESC)
  WHERE cohort_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_user
  ON analytics_events(pseudonymous_user_id, occurred_at DESC)
  WHERE pseudonymous_user_id IS NOT NULL;

COMMENT ON TABLE analytics_events IS
  'FR-025: 8-event analytics instrumentation. No PII. pseudonymous_user_id nullable (set to NULL by GDPR erasure).';
-- ============================================
-- 044: Annotation schema (FR-030, FR-031, FR-032)
-- ============================================
-- Stores per-message human annotations for model training/evaluation.
-- Blinding enforced: is_visible_to_peers = false until all annotators submit.
-- ============================================

CREATE TABLE IF NOT EXISTS annotations (
  annotation_id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  transcript_id        UUID        NOT NULL,   -- references sessions(id) logically (FK omitted to survive erasure)
  message_id           UUID        NOT NULL,   -- references session_messages(id) logically
  annotator_id         UUID        NOT NULL,   -- pseudonymous_user_id of annotator
  label_category       TEXT        NOT NULL,
  confidence           NUMERIC(3,2) NOT NULL   CHECK (confidence BETWEEN 0 AND 1),
  rationale            TEXT,
  adjudicated_label    TEXT,
  is_ground_truth      BOOLEAN     NOT NULL    DEFAULT FALSE,
  -- Blinding: hidden from peers until revealPeerLabels() is called after all annotators submit
  is_visible_to_peers  BOOLEAN     NOT NULL    DEFAULT FALSE,
  submitted_at         TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL    DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL    DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_annotations_transcript
  ON annotations(transcript_id);
CREATE INDEX IF NOT EXISTS idx_annotations_annotator
  ON annotations(annotator_id);
CREATE INDEX IF NOT EXISTS idx_annotations_transcript_annotator
  ON annotations(transcript_id, annotator_id);

COMMENT ON TABLE annotations IS
  'FR-031: Per-message human annotation records. is_visible_to_peers enforces FR-030 blinding.';
COMMENT ON COLUMN annotations.is_visible_to_peers IS
  'Set to TRUE by revealPeerLabels() only after all annotators for a transcript have submitted.';

-- ── sampling_runs ─────────────────────────────────────────────────────────
-- Tracks each stratified sampling operation for reproducibility.
-- random_seed is logged so any run can be reproduced deterministically.

CREATE TABLE IF NOT EXISTS sampling_runs (
  run_id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  random_seed          BIGINT      NOT NULL,
  config               JSONB       NOT NULL DEFAULT '{}',  -- stratification config snapshot
  sampled_transcript_ids  UUID[]   NOT NULL DEFAULT '{}',
  created_by           UUID,                               -- admin pseudonymous_user_id
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sampling_runs_created_at
  ON sampling_runs(created_at DESC);

COMMENT ON TABLE sampling_runs IS
  'FR-032: Stratified transcript sampling runs with deterministic seeds for reproducibility.';
-- Migration 045: Add supervisor_resolved and supervisor_dismissed audit event types (spec 032)
-- The API contract specifies these as distinct event types for supervisor escalation decisions.

-- Drop and recreate the CHECK constraint to include the new event types.
ALTER TABLE safety_flag_audit_events
  DROP CONSTRAINT IF EXISTS safety_flag_audit_events_event_type_check;

ALTER TABLE safety_flag_audit_events
  ADD CONSTRAINT safety_flag_audit_events_event_type_check
  CHECK (event_type IN ('created', 'resolved', 'escalated', 'false_positive', 'reopened', 'supervisor_resolved', 'supervisor_dismissed'));
-- Migration 046: Dynamic Permissions Engine tables, seed data, and group assignments
-- Feature: 035-dynamic-permissions-engine
-- Rollback: DROP TABLE permission_assignments; DROP TABLE principal_group_members;
--           DROP TABLE principal_groups; DROP TABLE permissions;
--           ALTER TABLE settings DROP COLUMN dynamic_permissions_enabled;

-- ============================================
-- permissions table
-- ============================================
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    scope_types VARCHAR(20)[] NOT NULL,
    is_system BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_permissions_key ON permissions(key);
CREATE INDEX IF NOT EXISTS idx_permissions_category ON permissions(category);

-- ============================================
-- principal_groups table
-- ============================================
CREATE TABLE IF NOT EXISTS principal_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT false,
    is_immutable BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_principal_groups_name ON principal_groups(name);

-- ============================================
-- principal_group_members table
-- ============================================
CREATE TABLE IF NOT EXISTS principal_group_members (
    principal_group_id UUID NOT NULL REFERENCES principal_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (principal_group_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_pgm_user ON principal_group_members(user_id);

-- ============================================
-- permission_assignments table
-- ============================================
CREATE TABLE IF NOT EXISTS permission_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    principal_type VARCHAR(20) NOT NULL CHECK (principal_type IN ('user', 'group')),
    principal_id UUID NOT NULL,
    securable_type VARCHAR(20) NOT NULL CHECK (securable_type IN ('platform', 'group')),
    securable_id UUID,
    effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (permission_id, principal_type, principal_id, securable_type, securable_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pa_unique_assignment
  ON permission_assignments (
    permission_id, principal_type, principal_id, securable_type,
    COALESCE(securable_id, '00000000-0000-0000-0000-000000000000')
  );
CREATE INDEX IF NOT EXISTS idx_pa_principal ON permission_assignments(principal_type, principal_id);
CREATE INDEX IF NOT EXISTS idx_pa_permission ON permission_assignments(permission_id);
CREATE INDEX IF NOT EXISTS idx_pa_securable ON permission_assignments(securable_type, securable_id);

-- ============================================
-- Settings column: feature flag
-- ============================================
ALTER TABLE settings ADD COLUMN IF NOT EXISTS dynamic_permissions_enabled BOOLEAN NOT NULL DEFAULT false;

-- ============================================
-- Updated_at triggers
-- ============================================
DROP TRIGGER IF EXISTS update_permissions_updated_at ON permissions;
CREATE TRIGGER update_permissions_updated_at BEFORE UPDATE ON permissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_principal_groups_updated_at ON principal_groups;
CREATE TRIGGER update_principal_groups_updated_at BEFORE UPDATE ON principal_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Seed: 48 permissions (all Permission enum values)
-- ============================================

-- Chat permissions (platform scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('chat:access', 'Chat Access', 'chat', '{platform}'),
('chat:send', 'Chat Send', 'chat', '{platform}'),
('chat:feedback', 'Chat Feedback', 'chat', '{platform}'),
('chat:debug', 'Chat Debug', 'chat', '{platform}')
ON CONFLICT (key) DO NOTHING;

-- Workbench permissions (platform + group scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('workbench:access', 'Workbench Access', 'workbench', '{platform,group}'),
('workbench:user_management', 'Workbench User Management', 'workbench', '{platform,group}'),
('workbench:research', 'Workbench Research', 'workbench', '{platform,group}'),
('workbench:moderation', 'Workbench Moderation', 'workbench', '{platform,group}'),
('workbench:privacy', 'Workbench Privacy', 'workbench', '{platform,group}'),
('workbench:group_dashboard', 'Workbench Group Dashboard', 'workbench', '{platform,group}'),
('workbench:group_users', 'Workbench Group Users', 'workbench', '{platform,group}'),
('workbench:group_research', 'Workbench Group Research', 'workbench', '{platform,group}')
ON CONFLICT (key) DO NOTHING;

-- Data permissions (platform scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('data:view_pii', 'Data View PII', 'data', '{platform}'),
('data:export', 'Data Export', 'data', '{platform}'),
('data:delete', 'Data Delete', 'data', '{platform}')
ON CONFLICT (key) DO NOTHING;

-- Review permissions (platform + group scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('review:access', 'Review Access', 'review', '{platform,group}'),
('review:submit', 'Review Submit', 'review', '{platform,group}'),
('review:flag', 'Review Flag', 'review', '{platform,group}'),
('review:tiebreak', 'Review Tiebreak', 'review', '{platform,group}'),
('review:cross_group', 'Review Cross Group', 'review', '{platform,group}'),
('review:team_dashboard', 'Review Team Dashboard', 'review', '{platform,group}'),
('review:escalation', 'Review Escalation', 'review', '{platform,group}'),
('review:assign', 'Review Assign', 'review', '{platform,group}'),
('review:deanonymize_request', 'Review Deanonymize Request', 'review', '{platform,group}'),
('review:deanonymize_approve', 'Review Deanonymize Approve', 'review', '{platform,group}'),
('review:commander_dashboard', 'Review Commander Dashboard', 'review', '{platform,group}'),
('review:configure', 'Review Configure', 'review', '{platform,group}'),
('review:reports', 'Review Reports', 'review', '{platform,group}'),
('review:supervise', 'Review Supervise', 'review', '{platform,group}'),
('review:supervision_config', 'Review Supervision Config', 'review', '{platform,group}')
ON CONFLICT (key) DO NOTHING;

-- Tag permissions (platform + group scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('tag:manage', 'Tag Manage', 'tag', '{platform,group}'),
('tag:create', 'Tag Create', 'tag', '{platform,group}'),
('tag:assign_user', 'Tag Assign User', 'tag', '{platform,group}'),
('tag:assign_session', 'Tag Assign Session', 'tag', '{platform,group}'),
('tester_tag:manage', 'Tester Tag Manage', 'tag', '{platform,group}')
ON CONFLICT (key) DO NOTHING;

-- Survey permissions (platform + group scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('survey:schema_manage', 'Survey Schema Manage', 'survey', '{platform,group}'),
('survey:schema_archive', 'Survey Schema Archive', 'survey', '{platform,group}'),
('survey:instance_manage', 'Survey Instance Manage', 'survey', '{platform,group}'),
('survey:instance_view', 'Survey Instance View', 'survey', '{platform,group}'),
('survey:response_view', 'Survey Response View', 'survey', '{platform,group}')
ON CONFLICT (key) DO NOTHING;

-- Security permissions (platform scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('security:view', 'Security View', 'security', '{platform}'),
('security:manage', 'Security Manage', 'security', '{platform}'),
('security:feature_flag', 'Security Feature Flag', 'security', '{platform}')
ON CONFLICT (key) DO NOTHING;

-- Group permissions (group scope)
INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('group:admit_users', 'Group Admit Users', 'group', '{group}'),
('group:view_surveys', 'Group View Surveys', 'group', '{group}'),
('group:view_chats', 'Group View Chats', 'group', '{group}'),
('group:view_members', 'Group View Members', 'group', '{group}'),
('group:manage_config', 'Group Manage Config', 'group', '{group}')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- Seed: 7 principal groups
-- ============================================
INSERT INTO principal_groups (name, description, is_system, is_immutable) VALUES
('Owners', 'Full system access — immutable', true, true),
('Security Admins', 'Permission system management — immutable', true, true),
('QA Specialists', 'Basic review and quality assurance', true, false),
('Researchers', 'Senior review and cross-group research', true, false),
('Supervisors', 'Review supervision and quality control', true, false),
('Moderators', 'Platform moderation and escalation management', true, false),
('Group Admins', 'Group-scoped administration', true, false)
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- Seed: Permission assignments for system groups
-- ============================================

-- Owners: Allow ALL permissions at platform scope
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Owners'
ON CONFLICT DO NOTHING;

-- Security Admins: WORKBENCH_ACCESS, SECURITY_VIEW, SECURITY_MANAGE, SECURITY_FEATURE_FLAG
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Security Admins'
  AND p.key IN ('workbench:access', 'security:view', 'security:manage', 'security:feature_flag')
ON CONFLICT DO NOTHING;

-- QA Specialists: matches ROLE_PERMISSIONS[QA_SPECIALIST]
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'QA Specialists'
  AND p.key IN (
    'chat:access', 'chat:send', 'chat:feedback', 'chat:debug',
    'review:access', 'review:submit', 'review:flag'
  )
ON CONFLICT DO NOTHING;

-- Researchers: matches ROLE_PERMISSIONS[RESEARCHER]
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Researchers'
  AND p.key IN (
    'chat:access',
    'workbench:access', 'workbench:research', 'workbench:moderation',
    'review:access', 'review:submit', 'review:flag', 'review:tiebreak',
    'review:cross_group', 'review:team_dashboard',
    'survey:schema_manage', 'survey:instance_manage', 'survey:instance_view', 'survey:response_view'
  )
ON CONFLICT DO NOTHING;

-- Supervisors: matches ROLE_PERMISSIONS[SUPERVISOR]
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Supervisors'
  AND p.key IN (
    'chat:access',
    'workbench:access', 'workbench:research', 'workbench:moderation',
    'review:access', 'review:submit', 'review:flag', 'review:tiebreak',
    'review:cross_group', 'review:team_dashboard',
    'review:supervise', 'review:supervision_config',
    'tag:create', 'tag:assign_user', 'tag:assign_session', 'tester_tag:manage',
    'survey:instance_manage', 'survey:instance_view'
  )
ON CONFLICT DO NOTHING;

-- Moderators: matches ROLE_PERMISSIONS[MODERATOR]
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Moderators'
  AND p.key IN (
    'chat:access',
    'workbench:access', 'workbench:user_management', 'workbench:moderation', 'workbench:research',
    'review:access', 'review:submit', 'review:flag', 'review:tiebreak',
    'review:cross_group', 'review:team_dashboard', 'review:escalation',
    'review:assign', 'review:deanonymize_request',
    'review:supervise',
    'tag:create', 'tag:assign_user', 'tag:assign_session', 'tester_tag:manage',
    'survey:schema_manage', 'survey:schema_archive',
    'survey:instance_manage', 'survey:instance_view', 'survey:response_view'
  )
ON CONFLICT DO NOTHING;

-- Group Admins: matches ROLE_PERMISSIONS[GROUP_ADMIN]
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Group Admins'
  AND p.key IN (
    'chat:access',
    'workbench:access', 'workbench:group_dashboard', 'workbench:group_users', 'workbench:group_research',
    'review:access', 'review:submit', 'review:flag', 'review:tiebreak',
    'review:team_dashboard', 'review:escalation', 'review:assign',
    'review:deanonymize_request', 'review:deanonymize_approve', 'review:commander_dashboard',
    'tag:assign_user', 'tag:assign_session'
  )
ON CONFLICT DO NOTHING;

-- ============================================
-- Seed: Map existing users to principal groups based on role
-- ============================================
INSERT INTO principal_group_members (principal_group_id, user_id)
SELECT pg.id, u.id
FROM users u
JOIN principal_groups pg ON
  (u.role = 'owner' AND pg.name = 'Owners') OR
  (u.role = 'researcher' AND pg.name = 'Researchers') OR
  (u.role = 'supervisor' AND pg.name = 'Supervisors') OR
  (u.role = 'moderator' AND pg.name = 'Moderators') OR
  (u.role = 'group_admin' AND pg.name = 'Group Admins') OR
  (u.role = 'qa_specialist' AND pg.name = 'QA Specialists')
WHERE u.role != 'user'
ON CONFLICT DO NOTHING;
-- Migration 047: Allow unlimited invite codes (max_uses = 0)
-- Part of spec 044 — invite codes should not expire by use count.

-- 1. Drop the old CHECK constraint that required max_uses >= 1
ALTER TABLE group_invite_codes
  DROP CONSTRAINT IF EXISTS valid_invite_max_uses;

-- 2. Add new CHECK constraint allowing 0 (unlimited)
ALTER TABLE group_invite_codes
  ADD CONSTRAINT valid_invite_max_uses CHECK (max_uses >= 0);

-- 3. Set all codes with the old default (1) to unlimited (0)
UPDATE group_invite_codes
SET max_uses = 0
WHERE max_uses = 1;

-- 4. Change the column default from 1 to 0 for future inserts
ALTER TABLE group_invite_codes
  ALTER COLUMN max_uses SET DEFAULT 0;
-- Migration 048: Synthetic Agents core tables
-- Feature: 045-synthetic-agents
-- Rollback: DROP TABLE agent_run_schedules; DROP TABLE agent_runs; DROP TABLE synthetic_agents;

-- ============================================
-- synthetic_agents table
-- ============================================
CREATE TABLE IF NOT EXISTS synthetic_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    persona_profile JSONB NOT NULL DEFAULT '{}',
    intents JSONB NOT NULL DEFAULT '[]',
    conversation_mode VARCHAR(20) NOT NULL CHECK (conversation_mode IN ('scripted', 'llm_driven')),
    scripted_flow JSONB,
    llm_config JSONB,
    memory_mode VARCHAR(20) NOT NULL CHECK (memory_mode IN ('accumulate', 'pre_seeded', 'reset_each_run')),
    initial_memory TEXT,
    driver_mode VARCHAR(10) NOT NULL CHECK (driver_mode IN ('api', 'browser')),
    target_environment_url VARCHAR(255) NOT NULL DEFAULT 'https://dev.mentalhelp.chat',
    survey_answers JSONB,
    status VARCHAR(10) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
    group_id UUID REFERENCES groups(id),
    max_concurrent_runs INTEGER NOT NULL DEFAULT 1,
    run_timeout_minutes INTEGER NOT NULL DEFAULT 30,
    retention_days INTEGER NOT NULL DEFAULT 90,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_synthetic_agents_user_id ON synthetic_agents(user_id);
CREATE INDEX IF NOT EXISTS idx_synthetic_agents_status ON synthetic_agents(status);
CREATE INDEX IF NOT EXISTS idx_synthetic_agents_group_id ON synthetic_agents(group_id);
CREATE INDEX IF NOT EXISTS idx_synthetic_agents_created_by ON synthetic_agents(created_by);

COMMENT ON TABLE synthetic_agents IS 'Synthetic agent definitions that drive automated chat sessions';
COMMENT ON COLUMN synthetic_agents.user_id IS 'Dedicated user account for the agent (1:1 mapping)';
COMMENT ON COLUMN synthetic_agents.persona_profile IS 'JSON persona profile: demographics, language style, emotional tone';
COMMENT ON COLUMN synthetic_agents.intents IS 'JSON array of conversation intents the agent will pursue';
COMMENT ON COLUMN synthetic_agents.conversation_mode IS 'scripted = follow scripted_flow; llm_driven = use llm_config';
COMMENT ON COLUMN synthetic_agents.memory_mode IS 'How conversation memory is handled across runs';
COMMENT ON COLUMN synthetic_agents.driver_mode IS 'api = direct API calls; browser = Playwright-driven browser session';
COMMENT ON COLUMN synthetic_agents.survey_answers IS 'Pre-configured survey answers for intake/invite surveys';
COMMENT ON COLUMN synthetic_agents.status IS 'draft = not runnable; active = runnable; archived = soft-deleted';
COMMENT ON COLUMN synthetic_agents.max_concurrent_runs IS 'Maximum simultaneous runs for this agent';
COMMENT ON COLUMN synthetic_agents.run_timeout_minutes IS 'Timeout per run in minutes';
COMMENT ON COLUMN synthetic_agents.retention_days IS 'Days to retain run data before cleanup';

-- ============================================
-- agent_runs table
-- ============================================
CREATE TABLE IF NOT EXISTS agent_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES synthetic_agents(id),
    trigger_type VARCHAR(10) NOT NULL CHECK (trigger_type IN ('manual', 'scheduled', 'event')),
    driver_mode_override VARCHAR(10) CHECK (driver_mode_override IN ('api', 'browser')),
    status VARCHAR(10) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
    session_id UUID REFERENCES sessions(id),
    route_to_review BOOLEAN NOT NULL DEFAULT false,
    messages_sent INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_log TEXT,
    error_category VARCHAR(30) CHECK (error_category IN ('driver_error', 'llm_error', 'timeout', 'auth_error', 'backend_error', 'cancelled')),
    run_config_snapshot JSONB NOT NULL DEFAULT '{}',
    schedule_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_agent_runs_agent_id ON agent_runs(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_runs_status ON agent_runs(status);
CREATE INDEX IF NOT EXISTS idx_agent_runs_agent_status ON agent_runs(agent_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_runs_session_id ON agent_runs(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_agent_runs_schedule_id ON agent_runs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_agent_runs_created_at ON agent_runs(created_at);

COMMENT ON TABLE agent_runs IS 'Individual execution records for synthetic agent runs';
COMMENT ON COLUMN agent_runs.trigger_type IS 'How the run was initiated: manual, scheduled, or event-driven';
COMMENT ON COLUMN agent_runs.driver_mode_override IS 'Overrides agent default driver_mode for this run';
COMMENT ON COLUMN agent_runs.session_id IS 'Chat session created by this run (set once session starts)';
COMMENT ON COLUMN agent_runs.route_to_review IS 'Whether to flag the resulting session for human review';
COMMENT ON COLUMN agent_runs.error_category IS 'Categorised error type for failed runs';
COMMENT ON COLUMN agent_runs.run_config_snapshot IS 'Snapshot of agent config at time of run for reproducibility';
COMMENT ON COLUMN agent_runs.schedule_id IS 'Link to schedule that triggered this run (if scheduled)';

-- ============================================
-- agent_run_schedules table
-- ============================================
CREATE TABLE IF NOT EXISTS agent_run_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES synthetic_agents(id),
    schedule_type VARCHAR(10) NOT NULL CHECK (schedule_type IN ('cron', 'event')),
    cron_expression VARCHAR(100),
    event_trigger VARCHAR(100),
    driver_mode_override VARCHAR(10) CHECK (driver_mode_override IN ('api', 'browser')),
    route_to_review BOOLEAN NOT NULL DEFAULT false,
    enabled BOOLEAN NOT NULL DEFAULT true,
    last_run_id UUID,
    next_run_at TIMESTAMP WITH TIME ZONE,
    cloud_scheduler_job_name VARCHAR(255),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT valid_schedule_config CHECK (
        (schedule_type = 'cron' AND cron_expression IS NOT NULL) OR
        (schedule_type = 'event' AND event_trigger IS NOT NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_agent_run_schedules_agent_id ON agent_run_schedules(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_run_schedules_event_trigger ON agent_run_schedules(event_trigger) WHERE schedule_type = 'event' AND enabled = true;
CREATE INDEX IF NOT EXISTS idx_agent_run_schedules_enabled ON agent_run_schedules(enabled);

COMMENT ON TABLE agent_run_schedules IS 'Schedule definitions for automated synthetic agent runs';
COMMENT ON COLUMN agent_run_schedules.schedule_type IS 'cron = time-based; event = triggered by system event';
COMMENT ON COLUMN agent_run_schedules.cron_expression IS 'Cron expression (required when schedule_type = cron)';
COMMENT ON COLUMN agent_run_schedules.event_trigger IS 'Event name to listen for (required when schedule_type = event)';
COMMENT ON COLUMN agent_run_schedules.cloud_scheduler_job_name IS 'GCP Cloud Scheduler job name for external scheduling';

-- ============================================
-- Updated_at triggers
-- ============================================
DROP TRIGGER IF EXISTS update_synthetic_agents_updated_at ON synthetic_agents;
CREATE TRIGGER update_synthetic_agents_updated_at BEFORE UPDATE ON synthetic_agents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_agent_run_schedules_updated_at ON agent_run_schedules;
CREATE TRIGGER update_agent_run_schedules_updated_at BEFORE UPDATE ON agent_run_schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Migration 049: Add synthetic agent columns to users and sessions tables
-- Feature: 045-synthetic-agents
-- Rollback: ALTER TABLE sessions DROP COLUMN synthetic_agent_id;
--           ALTER TABLE sessions DROP COLUMN source;
--           ALTER TABLE users DROP COLUMN is_synthetic;

-- ============================================
-- users table: synthetic flag
-- ============================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_synthetic BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_users_is_synthetic ON users(is_synthetic) WHERE is_synthetic = true;

COMMENT ON COLUMN users.is_synthetic IS 'True for user accounts owned by synthetic agents';

-- ============================================
-- sessions table: source and synthetic agent link
-- ============================================
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS source VARCHAR(10) NOT NULL DEFAULT 'user' CHECK (source IN ('user', 'synthetic'));
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS synthetic_agent_id UUID REFERENCES synthetic_agents(id);

CREATE INDEX IF NOT EXISTS idx_sessions_source ON sessions(source);
CREATE INDEX IF NOT EXISTS idx_sessions_synthetic_agent_id ON sessions(synthetic_agent_id) WHERE synthetic_agent_id IS NOT NULL;

COMMENT ON COLUMN sessions.source IS 'Origin of the session: user (human) or synthetic (agent-driven)';
COMMENT ON COLUMN sessions.synthetic_agent_id IS 'Link to the synthetic agent that created this session (NULL for human sessions)';
-- Migration 050: Seed synthetic agent permissions into dynamic permissions engine
-- Feature: 045-synthetic-agents (T018)
-- Depends on: 046_035-dynamic-permissions-tables.sql (permissions table + principal_groups)
-- Rollback: DELETE FROM permission_assignments WHERE permission_id IN
--           (SELECT id FROM permissions WHERE category = 'synthetic_agents');
--           DELETE FROM permissions WHERE category = 'synthetic_agents';

-- ============================================
-- Seed: 7 synthetic_agents permissions
-- ============================================
-- Note: synthetic_agents:run_production is NOT assigned to any role by default.
-- It must be explicitly granted via the dynamic permissions engine.

INSERT INTO permissions (key, display_name, category, scope_types) VALUES
('synthetic_agents:view', 'Synthetic Agents View', 'synthetic_agents', '{platform}'),
('synthetic_agents:run', 'Synthetic Agents Run', 'synthetic_agents', '{platform}'),
('synthetic_agents:schedule', 'Synthetic Agents Schedule', 'synthetic_agents', '{platform}'),
('synthetic_agents:create', 'Synthetic Agents Create', 'synthetic_agents', '{platform}'),
('synthetic_agents:edit', 'Synthetic Agents Edit', 'synthetic_agents', '{platform}'),
('synthetic_agents:delete', 'Synthetic Agents Delete', 'synthetic_agents', '{platform}'),
('synthetic_agents:run_production', 'Synthetic Agents Run Production', 'synthetic_agents', '{platform}')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- Permission assignments for system groups
-- Matches ROLE_PERMISSIONS from @mentalhelpglobal/chat-types
-- ============================================

-- QA Specialists: view + run
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'QA Specialists'
  AND p.key IN (
    'synthetic_agents:view',
    'synthetic_agents:run'
  )
ON CONFLICT DO NOTHING;

-- Researchers: view + run + schedule + create + edit
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Researchers'
  AND p.key IN (
    'synthetic_agents:view',
    'synthetic_agents:run',
    'synthetic_agents:schedule',
    'synthetic_agents:create',
    'synthetic_agents:edit'
  )
ON CONFLICT DO NOTHING;

-- Supervisors: view + run + schedule + create + edit + delete
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Supervisors'
  AND p.key IN (
    'synthetic_agents:view',
    'synthetic_agents:run',
    'synthetic_agents:schedule',
    'synthetic_agents:create',
    'synthetic_agents:edit',
    'synthetic_agents:delete'
  )
ON CONFLICT DO NOTHING;

-- Moderators: view + run + schedule + create + edit + delete
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Moderators'
  AND p.key IN (
    'synthetic_agents:view',
    'synthetic_agents:run',
    'synthetic_agents:schedule',
    'synthetic_agents:create',
    'synthetic_agents:edit',
    'synthetic_agents:delete'
  )
ON CONFLICT DO NOTHING;

-- Group Admins: view + run + schedule + create + edit + delete
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Group Admins'
  AND p.key IN (
    'synthetic_agents:view',
    'synthetic_agents:run',
    'synthetic_agents:schedule',
    'synthetic_agents:create',
    'synthetic_agents:edit',
    'synthetic_agents:delete'
  )
ON CONFLICT DO NOTHING;

-- Owners: already get ALL permissions via the wildcard in migration 046.
-- The ON CONFLICT DO NOTHING in the Owners seed handles these automatically.
-- But to be safe, explicitly grant them here too.
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Owners'
  AND p.category = 'synthetic_agents'
ON CONFLICT DO NOTHING;
-- ============================================
-- 051: Fix agent_runs schema (045-synthetic-agents)
-- ============================================
-- Adds missing duration_seconds column and timed_out status value.

-- 1. Add duration_seconds column
ALTER TABLE agent_runs
  ADD COLUMN IF NOT EXISTS duration_seconds NUMERIC;

COMMENT ON COLUMN agent_runs.duration_seconds IS
  'Computed duration in seconds (completed_at - started_at). Set by the model on completion/cancellation.';

-- 2. Expand status CHECK to include timed_out
ALTER TABLE agent_runs DROP CONSTRAINT IF EXISTS agent_runs_status_check;
ALTER TABLE agent_runs ADD CONSTRAINT agent_runs_status_check
  CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled', 'timed_out'));

-- 3. Add partial unique index for duplicate run prevention (one active run per agent)
CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_runs_one_active_per_agent
  ON agent_runs(agent_id)
  WHERE status IN ('queued', 'running');
-- ============================================
-- 052: Extend scoring criteria for workbench MVP (T007)
-- ============================================
-- Adds three new criteria to criteria_feedback: request_match,
-- autonomy_support, artificiality.  Updates the review_configuration
-- singleton to raise criteria_threshold from 7 to 8.
-- ============================================

BEGIN;

-- 1. Drop the existing CHECK constraint on criteria_feedback.criterion
--    (auto-named criteria_feedback_criterion_check from migration 013)
ALTER TABLE criteria_feedback
  DROP CONSTRAINT IF EXISTS criteria_feedback_criterion_check;

-- 2. Recreate CHECK with expanded set
ALTER TABLE criteria_feedback
  ADD CONSTRAINT criteria_feedback_criterion_check
    CHECK (criterion IN (
      'relevance',
      'empathy',
      'safety',
      'ethics',
      'clarity',
      'request_match',
      'autonomy_support',
      'artificiality'
    ));

-- 3. Update criteria threshold to 8 (was 7)
UPDATE review_configuration
  SET criteria_threshold = 8
  WHERE id = 1;

COMMIT;
-- ============================================
-- 053: Add dual-track review columns to sessions (T008)
-- ============================================
-- Adds supervision_status, expertise_status, and
-- supervision_updated_at to support the dual-track
-- review workflow (supervision + expert assessment).
-- ============================================

BEGIN;

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS supervision_status VARCHAR(20) DEFAULT 'none'
    CHECK (supervision_status IN ('none', 'ready', 'in_progress', 'supervised', 'rf_processed'));

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS expertise_status VARCHAR(20) DEFAULT 'none'
    CHECK (expertise_status IN ('none', 'awaiting', 'done'));

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS supervision_updated_at TIMESTAMPTZ DEFAULT NOW();

COMMIT;
-- ============================================
-- 054: Clinical tags for workbench MVP (T009)
-- ============================================
-- Extends tag_definitions to support 'clinical' category.
-- Creates review_clinical_tags for per-message clinical
-- tag assignments and review_clinical_tag_comments for
-- free-text clinical commentary per review.
-- ============================================

BEGIN;

-- 1. Extend tag_definitions category CHECK to include 'clinical'
--    (auto-named tag_definitions_category_check from migration 015)
ALTER TABLE tag_definitions
  DROP CONSTRAINT IF EXISTS tag_definitions_category_check;

ALTER TABLE tag_definitions
  ADD CONSTRAINT tag_definitions_category_check
    CHECK (category IN ('user', 'chat', 'clinical'));

-- 2. Review clinical tags — per-message tag assignments within a review
CREATE TABLE IF NOT EXISTS review_clinical_tags (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id         UUID NOT NULL REFERENCES session_reviews(id),
  message_id        UUID NOT NULL,
  tag_definition_id UUID NOT NULL REFERENCES tag_definitions(id),
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (review_id, message_id, tag_definition_id)
);

CREATE INDEX IF NOT EXISTS idx_clinical_tags_review
  ON review_clinical_tags(review_id);

-- 3. Review clinical tag comments — one optional comment per review
CREATE TABLE IF NOT EXISTS review_clinical_tag_comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id  UUID NOT NULL REFERENCES session_reviews(id) UNIQUE,
  comment    TEXT NOT NULL CHECK (length(comment) >= 10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMIT;
-- ============================================
-- 055: Extend risk_flags for message-level red flags (T010)
-- ============================================
-- Adds message_id (nullable — no FK since messages may be
-- external), flag_lifecycle_status, and description columns
-- to support per-message red flag tagging in reviews.
-- ============================================

BEGIN;

-- message_id — nullable UUID referencing a specific message
-- (no FK constraint: messages table may be in another service)
ALTER TABLE risk_flags
  ADD COLUMN IF NOT EXISTS message_id UUID;

-- flag_lifecycle_status — tracks whether the flag is pending moderator
-- review or has been activated
ALTER TABLE risk_flags
  ADD COLUMN IF NOT EXISTS flag_lifecycle_status VARCHAR(10) DEFAULT 'active'
    CHECK (flag_lifecycle_status IN ('pending', 'active'));

-- description — free-text description of the red flag
ALTER TABLE risk_flags
  ADD COLUMN IF NOT EXISTS description TEXT;

COMMIT;
-- ============================================
-- 056: Expert assignment and assessment tables (T011)
-- ============================================
-- Creates expert_tag_assignments (maps users to clinical
-- expertise tags) and expert_assessments (expert evaluations
-- of sessions routed by matching tags).
-- ============================================

BEGIN;

-- 1. Expert tag assignments — which clinical tags a user is expert in
CREATE TABLE IF NOT EXISTS expert_tag_assignments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id),
  tag_definition_id UUID NOT NULL REFERENCES tag_definitions(id),
  assigned_by       UUID NOT NULL REFERENCES users(id),
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, tag_definition_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_tags_tag_id
  ON expert_tag_assignments(tag_definition_id);

-- 2. Expert assessments — expert evaluations of sessions
CREATE TABLE IF NOT EXISTS expert_assessments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id   UUID NOT NULL,
  expert_id    UUID NOT NULL REFERENCES users(id),
  comment      TEXT NOT NULL CHECK (length(comment) >= 10),
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (session_id, expert_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_assessments_session
  ON expert_assessments(session_id);

COMMIT;
-- ============================================
-- 057: Change request and action token tables (T012)
-- ============================================
-- Creates change_requests for reviewers to request review
-- re-opens, and used_action_tokens for one-time email-based
-- approval/denial tokens.
-- ============================================

BEGIN;

-- 1. Change requests — review re-open requests
CREATE TABLE IF NOT EXISTS change_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id       UUID NOT NULL REFERENCES session_reviews(id),
  session_id      UUID NOT NULL,
  requester_id    UUID NOT NULL REFERENCES users(id),
  status          VARCHAR(10) DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'denied')),
  decided_by      UUID REFERENCES users(id),
  decided_at      TIMESTAMPTZ,
  decision_source VARCHAR(15)
    CHECK (decision_source IN ('email_token', 'web_ui')),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_change_requests_session
  ON change_requests(session_id);

CREATE INDEX IF NOT EXISTS idx_change_requests_status
  ON change_requests(status)
  WHERE status = 'pending';

-- 2. Used action tokens — one-time tokens for email-based decisions
CREATE TABLE IF NOT EXISTS used_action_tokens (
  token_hash  VARCHAR(64) PRIMARY KEY,
  redeemed_at TIMESTAMPTZ DEFAULT NOW(),
  action      VARCHAR(10) NOT NULL,
  request_id  UUID NOT NULL REFERENCES change_requests(id)
);

COMMIT;
-- ============================================
-- 058: TOTP enrollment and recovery code tables (T013)
-- ============================================
-- Creates totp_enrollments for storing encrypted TOTP
-- secrets per user, and totp_recovery_codes for backup
-- one-time recovery codes.
-- ============================================

BEGIN;

-- 1. TOTP enrollments — one per user
CREATE TABLE IF NOT EXISTS totp_enrollments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) UNIQUE,
  encrypted_secret BYTEA NOT NULL,
  iv               BYTEA NOT NULL,
  is_enrolled      BOOLEAN DEFAULT false,
  enrolled_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TOTP recovery codes — multiple per enrollment
CREATE TABLE IF NOT EXISTS totp_recovery_codes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES totp_enrollments(id) ON DELETE CASCADE,
  code_hash     VARCHAR(72) NOT NULL,
  is_used       BOOLEAN DEFAULT false,
  used_at       TIMESTAMPTZ
);

COMMIT;
-- ============================================
-- 059: Audit log table (T014)
-- ============================================
-- Creates an append-only audit_log table for tracking
-- security-relevant events (login, review actions, etc.).
--
-- NOTE: This table should be range-partitioned by timestamp
-- in production (e.g., monthly partitions) for query
-- performance and data lifecycle management. Partitioning
-- is deferred here pending production DBA review.
--
-- NOTE: In production, execute the following to enforce
-- append-only semantics (role names depend on environment):
--   REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;
--   REVOKE UPDATE, DELETE ON audit_log FROM app_role;
-- ============================================

BEGIN;

CREATE TABLE IF NOT EXISTS audit_log (
  id          BIGSERIAL PRIMARY KEY,
  event_type  VARCHAR(50)  NOT NULL,
  user_id     UUID,
  user_role   VARCHAR(30)  NOT NULL,
  timestamp   TIMESTAMPTZ  DEFAULT NOW(),
  ip_address  INET         NOT NULL,
  target_type VARCHAR(50)  NOT NULL,
  target_id   VARCHAR(100) NOT NULL,
  payload     JSONB        DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp
  ON audit_log(timestamp);

CREATE INDEX IF NOT EXISTS idx_audit_log_user
  ON audit_log(user_id);

CREATE INDEX IF NOT EXISTS idx_audit_log_event_type
  ON audit_log(event_type);

CREATE INDEX IF NOT EXISTS idx_audit_log_target
  ON audit_log(target_type, target_id);

COMMENT ON TABLE audit_log IS
  'Append-only audit trail. Should be range-partitioned by timestamp in production.';

COMMIT;
-- ============================================
-- 060: Supervision reports and incorrect answers (T015)
-- ============================================
-- Creates supervision_reports for supervisor narrative
-- assessments, incorrect_answers for marking specific
-- AI messages as incorrect, and extends session_reviews
-- and message_ratings with versioning/validation fields.
-- ============================================

BEGIN;

-- 1. Supervision reports — supervisor narrative per session
CREATE TABLE IF NOT EXISTS supervision_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID NOT NULL,
  supervisor_id UUID NOT NULL REFERENCES users(id),
  report_text   TEXT NOT NULL CHECK (length(report_text) >= 10),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (session_id, supervisor_id)
);

-- 2. Incorrect answers — mark specific AI messages as wrong
CREATE TABLE IF NOT EXISTS incorrect_answers (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  message_id UUID NOT NULL,
  marked_by  UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (session_id, message_id, marked_by)
);

-- 3. Add version tracking to session_reviews
ALTER TABLE session_reviews
  ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;

-- 4. Add validated_response field to message_ratings
ALTER TABLE message_ratings
  ADD COLUMN IF NOT EXISTS validated_response TEXT;

COMMIT;
-- ============================================
-- 061: Survey response annulment fields (T016)
-- ============================================
-- Adds soft-delete / annulment columns to survey_responses
-- (created in migration 024) to support GDPR-compliant
-- response annulment with a scheduled hard-delete window.
--
-- Table: survey_responses (verified in migration 024)
-- ============================================

BEGIN;

-- 1. Annulment timestamp — when the response was annulled
ALTER TABLE survey_responses
  ADD COLUMN IF NOT EXISTS annulled_at TIMESTAMPTZ;

-- 2. Annulled by — who performed the annulment
ALTER TABLE survey_responses
  ADD COLUMN IF NOT EXISTS annulled_by UUID REFERENCES users(id);

-- 3. Hard delete deadline — when the row can be physically purged
ALTER TABLE survey_responses
  ADD COLUMN IF NOT EXISTS hard_delete_after TIMESTAMPTZ;

-- 4. Partial index for efficient cleanup job queries
CREATE INDEX IF NOT EXISTS idx_survey_responses_annulled
  ON survey_responses(hard_delete_after)
  WHERE annulled_at IS NOT NULL;

COMMIT;
-- ============================================
-- 062: CX clinical playbooks — extend instrument types (052)
-- ============================================
-- Adds CX_DEP and CX_ANX instrument types for Dialogflow CX
-- depression and anxiety screening playbooks.
--
-- Extends CHECK constraints on:
--   assessment_scores.instrument_type
--   risk_thresholds.instrument_type
--   assessment_schedule.instrument_type
--
-- Seeds instrument_params via CTE in score_trajectories materialised view
-- (no separate table — params live in the WITH clause of 039_030).
--
-- Seeds risk_thresholds rows for the new instrument types.
-- ============================================

-- ----------------------------------------
-- 1. Extend assessment_scores instrument_type CHECK
-- ----------------------------------------
ALTER TABLE assessment_scores
  DROP CONSTRAINT IF EXISTS assessment_scores_instrument_type_check,
  ADD CONSTRAINT assessment_scores_instrument_type_check
    CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5', 'CX_DEP', 'CX_ANX'));

-- ----------------------------------------
-- 2. Extend risk_thresholds instrument_type CHECK
-- ----------------------------------------
ALTER TABLE risk_thresholds
  DROP CONSTRAINT IF EXISTS risk_thresholds_instrument_type_check,
  ADD CONSTRAINT risk_thresholds_instrument_type_check
    CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5', 'CX_DEP', 'CX_ANX'));

-- ----------------------------------------
-- 3. Extend assessment_schedule instrument_type CHECK
-- ----------------------------------------
ALTER TABLE assessment_schedule
  DROP CONSTRAINT IF EXISTS assessment_schedule_instrument_type_check,
  ADD CONSTRAINT assessment_schedule_instrument_type_check
    CHECK (instrument_type IN ('PHQ9', 'GAD7', 'PCL5', 'WHO5', 'CX_DEP', 'CX_ANX'));

-- ----------------------------------------
-- 4. Recreate score_trajectories materialised view with CX params
-- ----------------------------------------
-- The instrument_params CTE is embedded inside the materialised view
-- definition (039_030). We must DROP + CREATE to add new rows.
-- ----------------------------------------
DROP MATERIALIZED VIEW IF EXISTS score_trajectories;

CREATE MATERIALIZED VIEW score_trajectories AS
  WITH instrument_params AS (
    SELECT * FROM (VALUES
      ('PHQ9',  5.4,  0.89, 5),
      ('GAD7',  5.3,  0.92, 4),
      ('PCL5',  9.8,  0.94, 10),
      ('WHO5',  5.4,  0.84, 10),
      ('CX_DEP', 4.0, 0.85, 3),
      ('CX_ANX', 4.0, 0.85, 3)
    ) AS t(instrument_type, sd, reliability, cmi_threshold)
  ),

  scores_with_prev AS (
    SELECT
      ases.pseudonymous_user_id,
      asc_.instrument_type,
      asc_.total_score,
      ases.administered_at,
      LAG(asc_.total_score) OVER (
        PARTITION BY ases.pseudonymous_user_id, asc_.instrument_type
        ORDER BY ases.administered_at
      ) AS prev_score
    FROM assessment_scores  asc_
    JOIN assessment_sessions ases
      ON ases.assessment_session_id = asc_.assessment_session_id
    WHERE ases.pseudonymous_user_id IS NOT NULL
      AND ases.status = 'completed'
  )

  SELECT
    sp.pseudonymous_user_id,
    sp.instrument_type,
    sp.total_score,
    sp.administered_at,

    -- Rolling 30-day mean
    AVG(sp.total_score) OVER (
      PARTITION BY sp.pseudonymous_user_id, sp.instrument_type
      ORDER BY sp.administered_at
      RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
    )::NUMERIC(6,2)               AS rolling_30d_mean,

    -- Jacobson-Truax RCI = (score_now - score_prev) / SEdiff
    CASE
      WHEN sp.prev_score IS NULL THEN NULL
      ELSE ROUND(
        (sp.total_score - sp.prev_score)::NUMERIC
          / (ip.sd * SQRT(1.0 - ip.reliability) * SQRT(2.0)),
        3
      )
    END                           AS rci,

    -- CMI flag: score improved by >= cmi_threshold since last assessment
    CASE
      WHEN sp.prev_score IS NULL THEN FALSE
      ELSE (sp.prev_score - sp.total_score) >= ip.cmi_threshold
    END                           AS clinically_meaningful_improvement

  FROM scores_with_prev sp
  JOIN instrument_params ip USING (instrument_type)
WITH DATA;

-- Unique index required for CONCURRENTLY refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_score_trajectories_pk
  ON score_trajectories(pseudonymous_user_id, instrument_type, administered_at);

-- Re-schedule pg_cron refresh (safe no-op if pg_cron not installed)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'refresh-score-trajectories',
      '*/15 * * * *',
      'REFRESH MATERIALIZED VIEW CONCURRENTLY score_trajectories'
    );
  END IF;
END$$;

-- ----------------------------------------
-- 5. Seed risk_thresholds for CX instruments
-- ----------------------------------------
-- configured_by is NOT NULL with FK to users. Use the system user
-- (email = 'system@mentalhelp.global') if it exists; otherwise skip
-- seeding (will be populated via admin UI or CLI).
-- ----------------------------------------
DO $$
DECLARE
  v_system_user UUID;
BEGIN
  SELECT pseudonymous_user_id INTO v_system_user
    FROM users
    WHERE email = 'system@mentalhelp.global'
    LIMIT 1;

  IF v_system_user IS NULL THEN
    RAISE NOTICE '062: system user not found — skipping risk_thresholds seed (add via admin UI)';
    RETURN;
  END IF;

  INSERT INTO risk_thresholds (threshold_id, instrument_type, threshold_type, threshold_value, tier, configured_by, configured_at, effective_from)
  VALUES
    (gen_random_uuid(), 'CX_DEP', 'absolute',      '{"score": 11}'::jsonb,                  'urgent',   v_system_user, NOW(), NOW()),
    (gen_random_uuid(), 'CX_DEP', 'item_response',  '{"item_index": 17, "min_value": 1}'::jsonb, 'critical', v_system_user, NOW(), NOW()),
    (gen_random_uuid(), 'CX_ANX', 'absolute',      '{"score": 11}'::jsonb,                  'urgent',   v_system_user, NOW(), NOW()),
    (gen_random_uuid(), 'CX_ANX', 'item_response',  '{"item_index": 4, "min_value": 1}'::jsonb, 'routine',  v_system_user, NOW(), NOW())
  ON CONFLICT DO NOTHING;
END$$;
-- ============================================
-- 063: Extend users role CHECK constraint (055-fix-role-assignment)
-- ============================================
-- Adds 'expert', 'admin', and 'master' to the allowed values
-- for users.role. These roles were added to the UserRole enum
-- in chat-types as part of MVP 048 but the DB constraint was
-- never updated, causing 500 errors on role assignment.
-- ============================================

BEGIN;

-- Drop ALL role-related CHECK constraints on users table.
-- Migration 010 recreates 'valid_role' on every startup, and migration 016
-- creates 'users_role_check'. Both may coexist; LIMIT 1 would miss the second.
ALTER TABLE users DROP CONSTRAINT IF EXISTS valid_role;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users
    ADD CONSTRAINT users_role_check
    CHECK (role IN (
        'user',
        'qa_specialist',
        'researcher',
        'supervisor',
        'moderator',
        'group_admin',
        'owner',
        'expert',
        'admin',
        'master'
    ));

COMMIT;
-- 063: Conversation compaction (spec 056)
--
-- Adds the DB schema changes required for the conversation-compaction
-- feature (prevent Dialogflow CX 8192-token overflow via session rotation +
-- summarization). See docs/superpowers/specs/2026-04-17-conversation-
-- compaction-design.md § 5 for the full design, and
-- specs/056-conversation-compaction/data-model.md for field-by-field
-- descriptions.
--
-- All changes are additive with non-NULL defaults on new columns, so the
-- migration is fast (PG11+ metadata-only ALTER) and backward-compatible.
-- Rollback procedure is documented as a runbook entry (see research.md R11).
--
-- Safe to run with compaction_enabled = FALSE default; the feature ships
-- dark and is enabled via Workbench admin settings after dev soak.

BEGIN;

-- 1. per-message compaction flag + partial index.
-- The hot query is "select active (non-compacted) messages for a session",
-- so the index is partial on compacted_at IS NULL; it stays small as rows
-- drop out of the index when they are compacted.
ALTER TABLE messages
  ADD COLUMN compacted_at TIMESTAMPTZ NULL;

CREATE INDEX idx_messages_session_compacted
  ON messages(session_id)
  WHERE compacted_at IS NULL;

-- 2. per-session compaction state.
-- active_cx_session_id diverges from chat_sessions.id after the first
-- compaction rotates the CX-side session. Pre-existing rows are backfilled
-- below so they continue routing to their original CX session until
-- naturally compacted.
ALTER TABLE chat_sessions
  ADD COLUMN active_cx_session_id UUID NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN compaction_summary TEXT NULL,
  ADD COLUMN compaction_summary_updated_at TIMESTAMPTZ NULL,
  ADD COLUMN compactions_count INTEGER NOT NULL DEFAULT 0;

-- Backfill: override the fresh gen_random_uuid() default with the row's own
-- id for every pre-existing session. This preserves continuity for in-flight
-- sessions; new sessions created after this migration get a random UUID
-- from the column default.
UPDATE chat_sessions
  SET active_cx_session_id = id;

-- 3. global compaction settings (singleton `settings` row).
-- Bounds are enforced at the API validator layer (see admin-settings-patch
-- contract), not in the DB; the defaults here are the post-soak recommended
-- starting values.
ALTER TABLE settings
  ADD COLUMN compaction_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN compaction_ratio NUMERIC(3,2) NOT NULL DEFAULT 0.33,
  ADD COLUMN compaction_max_messages INTEGER NOT NULL DEFAULT 40,
  ADD COLUMN compaction_soft_token_budget INTEGER NOT NULL DEFAULT 5500;

COMMIT;
-- ============================================
-- 064: Reviewer Review Queue foundation (feature 058)
-- ============================================
-- Jira Epic: MTB-1449
-- Spec: client-spec/specs/058-reviewer-review-queue/spec.md
-- Data model: client-spec/specs/058-reviewer-review-queue/data-model.md
--
-- This migration is the Phase-2 (Foundational) schema delta for the
-- Reviewer Review Queue feature. It is strictly ADDITIVE — no column
-- is dropped or renamed; no existing data is mutated. Existing 054–
-- 060 tables (session_reviews, message_ratings, review_clinical_tags,
-- review_clinical_tag_comments, risk_flags, change_requests,
-- expert_tag_assignments, expert_assessments, audit_log, supervision_
-- reports, incorrect_answers) are extended or joined to, not replaced.
--
-- Delta introduced by this migration:
--   1. tag_definitions: language_group (JSONB, default ['uk']),
--      deleted_at (TIMESTAMPTZ, nullable)               (FR-021a, FR-021b, FR-024c)
--   2. expert_tag_assignments: language_group (JSONB, default ['uk'])   (FR-021a)
--   3. audit_log: legal_hold (BOOL, default FALSE),
--      tier (VARCHAR(10), default 'hot',
--            CHECK tier IN ('hot','warm','cold'))        (FR-050a, FR-050b)
--   4. review_tag_assignments (new table) — session-level Review Tag
--      attachments visible across Reviewers in the Space.             (FR-024a, FR-024f)
--   5. notifications (new table) — Reviewer-targeted notifications
--      for three in-scope categories (FR-039a, FR-039b).
-- ============================================

BEGIN;

-- ============================================
-- 1. Tag-level language group + soft-delete
-- ============================================
ALTER TABLE tag_definitions
  ADD COLUMN IF NOT EXISTS language_group JSONB NOT NULL DEFAULT '["uk"]'::jsonb;

ALTER TABLE tag_definitions
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tag_definitions_deleted_at
  ON tag_definitions(deleted_at);

COMMENT ON COLUMN tag_definitions.language_group IS
  'FR-021a / FR-024c — locales in which the tag is offered to Reviewers. Default ["uk"] for rows migrated from feature 048; Tag Center admin UI updates via the parallel feature.';

COMMENT ON COLUMN tag_definitions.deleted_at IS
  'FR-021b — soft-delete timestamp. New attachments forbidden once set; existing attachments continue to surface with a "(deleted)" prefix on the Reviewer chip.';

-- ============================================
-- 2. Expert-assignment language group
-- ============================================
ALTER TABLE expert_tag_assignments
  ADD COLUMN IF NOT EXISTS language_group JSONB NOT NULL DEFAULT '["uk"]'::jsonb;

COMMENT ON COLUMN expert_tag_assignments.language_group IS
  'FR-021a — Expert routing requires the assignment language_group to cover the session.language. Default ["uk"] for legacy rows.';

-- ============================================
-- 3. Audit log retention fields
-- ============================================
ALTER TABLE audit_log
  ADD COLUMN IF NOT EXISTS legal_hold BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE audit_log
  ADD COLUMN IF NOT EXISTS tier VARCHAR(10) NOT NULL DEFAULT 'hot';

ALTER TABLE audit_log
  DROP CONSTRAINT IF EXISTS audit_log_tier_check;

ALTER TABLE audit_log
  ADD CONSTRAINT audit_log_tier_check
    CHECK (tier IN ('hot', 'warm', 'cold'));

CREATE INDEX IF NOT EXISTS idx_audit_log_tier
  ON audit_log(tier);

CREATE INDEX IF NOT EXISTS idx_audit_log_legal_hold
  ON audit_log(legal_hold)
  WHERE legal_hold = TRUE;

COMMENT ON COLUMN audit_log.legal_hold IS
  'FR-050b — pass-through flag. Entries with legal_hold = TRUE are NEVER purged by the retention job regardless of age. Feature 058 never sets this; reserved for the upstream legal-hold lifecycle feature.';

COMMENT ON COLUMN audit_log.tier IS
  'FR-050a — retention tier computed by the archival job. hot = 0-12 mo (online, full latency), warm = 12-36 mo (online, degraded SLA), cold = 36-60 mo (restore-on-request). Purged after 60 mo unless legal_hold = TRUE.';

-- ============================================
-- 4. Review Tag assignments (session-level)
-- ============================================
-- Review Tags are organisational labels (e.g. loop-regression, compat-tag3)
-- attached by Reviewers at session level — distinct from the per-message
-- Clinical Tag attachments in review_clinical_tags. Visible across every
-- Reviewer in the owning Space (unlike Clinical Tags, which are private
-- per Reviewer per FR-023).
CREATE TABLE IF NOT EXISTS review_tag_assignments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id        UUID NOT NULL,
  tag_definition_id UUID NOT NULL REFERENCES tag_definitions(id),
  attached_by       UUID NOT NULL REFERENCES users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (session_id, tag_definition_id)
);

CREATE INDEX IF NOT EXISTS idx_review_tag_assignments_session
  ON review_tag_assignments(session_id);

CREATE INDEX IF NOT EXISTS idx_review_tag_assignments_tag
  ON review_tag_assignments(tag_definition_id);

COMMENT ON TABLE review_tag_assignments IS
  'FR-024a..f — session-level Review Tag attachments. Unlike review_clinical_tags (per-message, per-reviewer, private), review_tag_assignments are session-level and visible across all Reviewers in the owning Space.';

-- ============================================
-- 5. Reviewer-targeted notifications
-- ============================================
-- Three in-scope categories per FR-039b. Other categories are
-- explicitly out of scope for feature 058; the subsystem remains
-- extensible without schema change.
CREATE TABLE IF NOT EXISTS notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id),
  category   VARCHAR(40) NOT NULL,
  payload    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at    TIMESTAMPTZ,
  CONSTRAINT notifications_category_check CHECK (
    category IN (
      'change_request.decision',
      'red_flag.supervisor_followup',
      'space.membership_change'
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id, read_at)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_latest
  ON notifications(user_id, created_at DESC);

COMMENT ON TABLE notifications IS
  'FR-039a / FR-039b — Reviewer-targeted notifications surfaced through the persistent banner + header bell-icon list. Explicit dismiss emits a notification.read audit log entry.';

COMMIT;
-- Feature 058 / US-3 / T095 — per-(message, reviewer) clinical tag comments.
--
-- Spec FR-022 (Round 2 Q5 clarification) requires each clinical tag
-- comment to be scoped to a single (message, reviewer) pair, not to the
-- entire session. The original migration 054_048-clinical-tags created
-- `review_clinical_tag_comments(review_id, comment)` which is a
-- session-level comment applied across ALL tagged messages. That is
-- kept as-is for backward-compat reads but the Reviewer UI will stop
-- writing to it and use this new table instead.
--
-- Additive only: no drops, no renames. Safe to roll forward on dev.

CREATE TABLE IF NOT EXISTS review_message_tag_comments (
    review_id   UUID        NOT NULL REFERENCES session_reviews(id) ON DELETE CASCADE,
    message_id  UUID        NOT NULL,
    comment     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (review_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_review_message_tag_comments_review
    ON review_message_tag_comments(review_id);

COMMENT ON TABLE review_message_tag_comments IS
    'Feature 058 / FR-022 — per-(message, reviewer) clinical tag comment. '
    'Each row is the comment a single Reviewer attached to the clinical '
    'tags they placed on a single message. Legacy session-level comments '
    'continue to live in review_clinical_tag_comments for historical data.';
-- Feature 058 / FR-024a (2026-04-22)
--
-- Owner reported on dev that the Reviewer (Researcher role)
-- couldn't attach Review Tags at the session level. The spec
-- (spec.md line 777, FR-024a) is explicit:
--
--   "The Reviewer MUST be able to attach one or more Review
--    Tags at the session level (not at the message level)
--    using a dedicated 'Tags:' control above the transcript."
--
-- The Reviewer surface gates the 'Add tag…' input on
-- `Permission.TAG_ASSIGN_SESSION`, which the static
-- `ROLE_PERMISSIONS[RESEARCHER]` mapping in chat-types@<=1.22.0
-- did NOT grant. The paired chat-types bump (1.23.0) adds it
-- to the static map; this migration adds the same grant to
-- the DB-resolved path so `dynamicPermissionsEnabled=true`
-- environments match.
--
-- Idempotent: `ON CONFLICT DO NOTHING` ensures re-running the
-- migration (or deploying to an env that already has the
-- assignment) is a no-op.
INSERT INTO permission_assignments (permission_id, principal_type, principal_id, securable_type, effect)
SELECT p.id, 'group', pg.id, 'platform', 'allow'
FROM permissions p, principal_groups pg
WHERE pg.name = 'Researchers'
  AND p.key = 'tag:assign_session'
ON CONFLICT DO NOTHING;
-- ============================================
-- 067: Reviewer MVP gaps (feature 059)
-- ============================================
-- Jira Epic: MTB-1449
-- Spec: client-spec/specs/059-reviewer-mvp-gaps/spec.md
--
-- Strictly ADDITIVE migration — no columns dropped or renamed.
--
-- Delta introduced by this migration:
--   1. settings: verbose_autosave_failures (BOOL, default FALSE)
--   2. settings: inactivity_timeout_minutes (INTEGER, default 30)
--   3. audit_log: legal_hold (BOOL, default FALSE) — already added
--      by 064_058; repeated here with IF NOT EXISTS for idempotency.
-- ============================================

BEGIN;

-- ============================================
-- 1. Verbose autosave failure logging toggle
-- ============================================
ALTER TABLE settings
  ADD COLUMN IF NOT EXISTS verbose_autosave_failures BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN settings.verbose_autosave_failures IS
  'Feature 059 — when TRUE, autosave failures emit detailed error payloads to the audit log instead of silent swallows.';

-- ============================================
-- 2. Session inactivity timeout (minutes)
-- ============================================
ALTER TABLE settings
  ADD COLUMN IF NOT EXISTS inactivity_timeout_minutes INTEGER NOT NULL DEFAULT 30;

COMMENT ON COLUMN settings.inactivity_timeout_minutes IS
  'Feature 059 — server-side session inactivity timeout in minutes. Sessions with no user activity beyond this threshold are expired by the cleanup job.';

-- ============================================
-- 3. Audit log legal hold (idempotent)
-- ============================================
-- Already present from 064_058-reviewer-review-queue.sql; included
-- here with IF NOT EXISTS so the migration is safe to run standalone.
ALTER TABLE audit_log
  ADD COLUMN IF NOT EXISTS legal_hold BOOLEAN NOT NULL DEFAULT FALSE;

COMMIT;
