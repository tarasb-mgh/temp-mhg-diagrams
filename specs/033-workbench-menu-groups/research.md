# Research: Workbench Sidebar Menu Reorganization (033)

## Scope

Technical research for sidebar menu grouping in `workbench-frontend`, covering state management, icon selection, localization, and group data structure design.

## Decision 1: Collapse State Storage Mechanism

- **Decision**: Use Zustand `workbenchStore` with `persist` middleware to store collapse state in `localStorage`.
- **Rationale**: The store already uses `persist` with `partialize` for `piiMasked`. Adding `navGroupCollapsed: Record<string, boolean>` to the partialize function gives cross-session persistence (survives page refresh, not just SPA navigation) with zero additional dependencies. This exceeds FR-003's "same browser session" requirement by also persisting across sessions — better UX at no cost.
- **Alternatives considered**:
  - React component state only (rejected: resets on every mount, does not survive SPA navigation between routes)
  - `sessionStorage` via custom hook (rejected: works but adds a parallel persistence layer when Zustand persist already handles this)
  - Backend-persisted preference (rejected: over-engineered for a UI preference, adds API surface)

## Decision 2: NavGroup Data Structure

- **Decision**: Define `NavGroupConfig` interface with `id`, `labelKey`, `items` array, and optional `collapsible` boolean. Keep `NavItemConfig` interface unchanged (add optional `group` field for future extensibility but assign groups via the group config, not the item).
- **Rationale**: Grouping items by a declarative config array (`navGroups: NavGroupConfig[]`) makes it trivial to reorder groups, add items, or reassign items between groups — satisfying FR-012 (data-driven group assignment). Keeping `NavItemConfig` unchanged minimizes diff and preserves the existing permission filtering logic.
- **Alternatives considered**:
  - Add `group: string` field to each `NavItemConfig` and group dynamically (rejected: requires runtime grouping logic and makes visual ordering implicit rather than explicit)
  - Separate config file/JSON (rejected: adds indirection; the nav config is small enough to live in-component)

## Decision 3: Icon Selection for New and Changed Items

- **Decision**: Use the following icon mapping from `lucide-react` (all verified as available in `lucide-react@0.460.0`):

| Item | Current Icon | New Icon | Reason |
| ---- | ------------ | -------- | ------ |
| Review Queue | Microscope | ClipboardCheck | Distinguishes from research; matches "review checklist" mental model |
| Review Dashboard | (new) | BarChart3 | Standard dashboard/analytics icon |
| Reports | FileBarChart | FileBarChart | Retained — unique within new grouping |
| Team Dashboard | (new) | UsersRound | Distinct from Users (UserCog) and Group Users (Users) |
| Escalations | (new) | AlertTriangle | Universal "attention needed" signal |
| Review Tags | Tag | Tags | Plural variant distinguishes from Tester Tags (Tag) |
| Review Settings | (new) | Wrench | Standard config/settings tool icon, distinct from Settings (Settings) |
| Survey Templates | FileBarChart | FileText | Matches "template/document" mental model |
| Survey Instances | FileBarChart | ListChecks | Matches "instance list with status" mental model |
| Users | Users | UserCog | Admin/management connotation |
| Groups | Users | Building2 | Organization/structure connotation |
| Approvals | CheckCircle | UserCheck | User-focused approval action |
| Tester Tags | Tag | Tag | Retained — unique within new grouping |
| Privacy | Shield | ShieldCheck | Slight variant adds "verified/controlled" connotation |
| Group Chats | Microscope | MessageSquare | Chat/conversation connotation |
| Group Surveys | FileBarChart | ClipboardList | List/survey connotation distinct from Survey Instances |
| Group headings | n/a | n/a | Group headings do not have icons; they use text labels with chevron indicators |

- **Rationale**: Every icon is now unique across the full sidebar. Icons were chosen for semantic match to the item's purpose, not just visual distinctness.
- **Alternatives considered**:
  - Keep duplicate icons and differentiate only by label (rejected: violates FR-006 and compounds the discoverability problem identified in 029)
  - Use custom SVG icons (rejected: unnecessary when lucide-react provides sufficient variety)

## Decision 4: Localization Key Naming Convention

- **Decision**: New keys follow the existing `workbench.nav.` prefix pattern. Group heading keys use `workbench.nav.group.{groupId}` pattern. Renamed items get new keys while old keys are preserved for backward compatibility during rollout.

| Key | en | uk | ru |
| --- | -- | -- | -- |
| `workbench.nav.group.reviews` | Reviews | Рецензування | Рецензирование |
| `workbench.nav.group.surveys` | Surveys | Опитування | Опросы |
| `workbench.nav.group.peopleAccess` | People & Access | Люди та доступ | Люди и доступ |
| `workbench.nav.reviewQueue` | Review Queue | Черга рецензій | Очередь рецензий |
| `workbench.nav.reviewDashboard` | Review Dashboard | Дашборд рецензій | Дашборд рецензий |
| `workbench.nav.teamDashboard` | Team Dashboard | Дашборд команди | Дашборд команды |
| `workbench.nav.escalations` | Escalations | Ескалації | Эскалации |
| `workbench.nav.reviewTags` | Review Tags | Теги рецензій | Теги рецензий |
| `workbench.nav.reviewSettings` | Review Settings | Налаштування рецензій | Настройки рецензий |
| `workbench.nav.surveyTemplates` | Survey Templates | Шаблони опитувань | Шаблоны опросов |
| `workbench.nav.users` | Users | Користувачі | Пользователи |
| `workbench.nav.groups` | Groups | Групи | Группы |
| `workbench.nav.testerTags` | Tester Tags | Теги тестувальників | Теги тестировщиков |
| `workbench.nav.privacy` | Privacy | Конфіденційність | Конфиденциальность |
| `workbench.nav.groupChats` | Group Chats | Чати групи | Чаты группы |

- **Rationale**: Consistent naming pattern, clean i18n key hierarchy, and shorter/clearer labels in all three languages.
- **Alternatives considered**:
  - Reuse existing keys with modified values (rejected: breaks any external reference to the old key-value mapping)
  - Flat key structure without group prefix (rejected: loses organizational clarity as key count grows)

## Decision 5: Group Resources Block Position and Behavior

- **Decision**: The Group Resources contextual block renders between the last static collapsible group (People & Access) and the bottom-pinned Settings item. It retains its current visual treatment (bordered card with "Group resources" label). It is not collapsible — it either appears (when a group is selected) or is absent.
- **Rationale**: Per clarification Q4, keeping it at the bottom maintains stable positions for all static items. Making it non-collapsible is consistent with its current behavior and avoids adding collapse logic to a contextual block that already hides/shows based on group selection.
- **Alternatives considered**:
  - Make Group Resources a collapsible group (rejected: it's already conditionally visible; adding collapse creates two visibility mechanisms)
  - Merge Group Resources into the People & Access group (rejected: mixes static and context-dependent items, violating FR-009)

## Decision 6: Breadcrumb and Active-State Integration

- **Decision**: The existing breadcrumb bar in `WorkbenchLayout.tsx` continues to work with the new nav structure unchanged. The `isActive` function and `activeNavItem` calculation remain the same — they operate on `path` matching, which is independent of grouping. The only change is that the `allNavItems` concatenation must include the newly surfaced review sub-routes.
- **Rationale**: The breadcrumb derives from the active nav item's label key and the URL path segments. Since we're not changing routes or the path-based matching algorithm, the breadcrumb works automatically.
- **Alternatives considered**:
  - Build group-aware breadcrumb (e.g., "Workbench > Reviews > Team Dashboard") (rejected: adds complexity; the current "Workbench > [section] > [trailing path]" pattern is sufficient)
