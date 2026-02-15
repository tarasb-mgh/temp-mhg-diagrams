# Data Model: Split Chat and Workbench Frontend + Backend

Conceptual entities for delivery, validation, and operations across split
frontend/backend surfaces.

## Entity: ExperienceSurface

**Purpose**: User-facing application surface (`chat`, `workbench`).

**Fields**:
- `id` (string): Surface identifier
- `frontendHost` (string): Canonical FE host by environment
- `entryRoute` (string): Canonical entry path
- `primaryActions` (string[]): In-scope critical actions
- `hiddenActions` (string[]): Out-of-surface actions

**Validation rules**:
- Each surface MUST map to exactly one canonical frontend host per environment.
- Surface actions MUST not include restricted actions from the other surface.

## Entity: BackendServiceSurface

**Purpose**: Independently deployable API/service boundary for each surface.

**Fields**:
- `id` (string): `chat-api` or `workbench-api`
- `apiHost` (string): Canonical API host by environment
- `deployableUnit` (string): Service deployment boundary
- `scalingPolicy` (string): Independent scaling policy reference
- `routeNamespace` (string[]): Supported route groups

**Validation rules**:
- Chat and workbench backend services MUST be independently deployable.
- API hostnames MUST be unique per service and environment.

## Entity: AccessPolicy

**Purpose**: Authorization and capability exposure policy across FE/BE surfaces.

**Fields**:
- `surfaceId` (string): FE surface
- `backendServiceId` (string): BE surface
- `allowedRoles` (string[]): Authorized role set
- `deniedBehavior` (string): UX/system behavior on denial
- `fallbackRoute` (string): Recovery route

**Validation rules**:
- Workbench policy MUST include explicit role requirements.
- Denied behavior MUST not leak restricted backend data contracts.

## Entity: RouteMappingRule

**Purpose**: Compatibility mapping from legacy routes to canonical hosts/routes.

**Fields**:
- `sourceRoutePattern` (string)
- `targetHost` (string)
- `targetRoute` (string)
- `status` (string): `active` or `sunset`

**Validation rules**:
- Active legacy routes MUST resolve deterministically.
- Mappings MUST preserve policy boundaries.

## Entity: DomainTopology

**Purpose**: Environment-specific canonical FE/API host mapping.

**Fields**:
- `environment` (string): `prod` or `dev`
- `chatFrontendHost` (string)
- `chatApiHost` (string)
- `workbenchFrontendHost` (string)
- `workbenchApiHost` (string)

**Validation rules**:
- Chat hosts remain unchanged per environment policy.
- Workbench hosts MUST follow dedicated FE/API split pattern.

## Relationships

- `ExperienceSurface` 1..1 `BackendServiceSurface`
- `AccessPolicy` links FE and BE surfaces
- `DomainTopology` provides environment host bindings for both surfaces
- `RouteMappingRule` references canonical hosts from `DomainTopology`

## State Transitions

### Session/surface transition state

`chat-surface-active` <-> `workbench-surface-active` (policy-gated)  
`request-restricted` -> `access-denied` -> `fallback-routed`

### Deployment/scaling state

`chat-api-scaled` and `workbench-api-scaled` are independent and MUST NOT
require coupled scaling operations.
