# Fail-closed local NPC startup wrapper — proposal for review

Status: **DESIGN ONLY, 2026-10-26**. No wrapper exists in this change. No command in this proposal grants permission to run it. Root owns gameplay QA and reviews the exact implementation, pins and runtime scope before any future execution.

## Problem and intended result

The verified local recovery required three separate actions: boot the existing VM, start its existing NPC database/game containers in order, and recover stale private X99 display files before starting the native programs. `restartPolicy=no` and map autostart=false are deliberate current settings. The current startup script does not guard stale display state after an unclean stop.

An eventual wrapper should produce one bounded, allowlisted health report. With a separately selected apply mode it may perform only the required existing-resource starts and the reviewed stale-display recovery. On an already healthy server it must perform no mutation, including when a legitimate gameplay session is active. A partial or uncertain operation must stop with an explicit pending/unknown result rather than repeat it.

Source baseline: CoreVM `b81ccd83608bb7ec23f86316bb5708c7d3536b99`, draft [PR 1](https://github.com/DarkStoryLand/CoreVM/pull/1). The [manual runbook](../11_LOCAL_DSL_TEST_STARTUP.md) and [2026-10-26 receipt](../evidence/20261026-local-dsl-test-startup.json) are historical evidence, not a perpetual current readiness grant.

## Proposed implementation write set (not yet approved or created)

| New file | Purpose |
| --- | --- |
| `scripts/dsl_local_qa_startup.py` | Standard-library Windows orchestrator with `observe` default and explicit `start --apply` mode |
| `scripts/dsl_local_qa_startup_remote.py` | Fixed remote Python operations, selected by enum; no arbitrary shell/SQL execution interface |
| `tests/test_dsl_local_qa_startup.py` | Offline state-machine and transport-failure tests with fake processes/filesystems |
| `docs/11_LOCAL_DSL_TEST_STARTUP.md` | Link reviewed wrapper usage only after source review and appropriate validation |

This proposal itself adds only this document and the adjacent design README. A future implementation must use an isolated CoreVM branch at an agreed immutable base, preserving dirty files in the shared CoreVM checkout. No DSL source, shared MCP files, game assets, credentials, VMX, guest configuration or image may be edited by implementation work.

## Pinned target and current-IP handling

The target is the existing `F:/DarkStory/VMs/dsl-test/dsl-test.vmx`, controlled through the installed `D:/VMware/VMware Workstation/vmrun.exe`. Resolve the exact normalized path and confirm its expected VM identity/MAC before any power operation. List running VMs once and retain an identity projection for the unrelated existing VM; never operate on that VM.

Use current guest IP from Tools, or a fresh exact-MAC DHCP lease when Tools is unavailable. Historical IP `192.168.188.135` alone is not proof of identity. Only the approved VMnet8 subnet is a candidate. Do not scan a subnet, fall back to 168, use loopback as the guest target, change DHCP/NAT/firewall settings, or repoint game configuration automatically.

Strict SSH uses the external `dsl.stage.ssh` and `dsl.stage.knownHosts` references from a caller-selected, validated reference file. Reference paths may be read internally; never print the reference object or key material. Keep BatchMode, strict host-key verification and bounded connection timeouts. A changed IP without a matching existing known-host entry is a diagnostic stop requiring identity review, not permission to bypass verification or alter known_hosts. Require remote hostname `dsl-test` before guest operations.

Check that Docker published-host bindings match the actual current guest IP. An IP change can leave the existing game container bound to an unavailable old address. Report the mismatch and stop; container recreation/rebinding is outside this wrapper.

## Exact operational boundary

Only these existing containers may be started:

- `dsl-origin-npc-mssql-20261024`
- `dsl-origin-npc-qa-20261024`

Only these native programs may be started, in order: `distribute`, `agent`, `map1`. Other maps stay in their observed states. Legacy and progression resources are protected observations, not dependencies to start.

Require the reviewed component manifest before applying: three native EXEs, NPC supervisord.conf, start.sh and wine_odbc.reg. Initial expected values are in the historical receipt; a newly approved version requires a new reviewed manifest. MapServer currently hashes to `67e1a403b5504caa9385b4695e8145a255fd8ea387f51f6cfa45411612630c5a`. Never copy or deploy bytes to make a hash match.

The only permitted filesystem deletions are `/tmp/.X99-lock` and `/tmp/.X11-unix/X99` inside the exact NPC container after all stale-state guards pass. This is not permission to clear a directory, delete locks in the VM host namespace, remove Wine prefix files, or touch live display state.

No provision/prepare/recreate, image pull/build, deploy, binary/config copy, restart-policy change, SQL DDL/DML, restore, fixture healing, login-session deletion, version-allowlist change, broad service restart, Windows input or game launch. Normal DB/native startup can itself write internally; the claim is absence of operator-issued SQL writes, not global zero writes.

## State machine

| State | Read gate | Apply action, if explicitly enabled | Failure behavior |
| --- | --- | --- | --- |
| Validate | Exact refs, VM path/identity, reviewed component manifest and scope | None | Stop before mutation |
| Observe VM | Exact VM running state | Start exact stopped VM once, nogui | Unknown outcome: observe only, no repeated power action |
| Discover | Tools/current exact-MAC lease; expected subnet | None | No guessed IP/fallback |
| Identity | Strict SSH, hostname, current bindings, ownership/lease prerequisites | None | Stop; no host-key repair |
| Observe profile | Exact container identities/states; protected resources; program states | None | Missing/unexpected resources are not recreated |
| Warm ready | DB/select readiness, Xvfb/socket, all three programs, TCP | None | Return ready observation; do not disturb an active session |
| Recovery gate | Root-provided current QA ownership/lease projection; owned QA login rows=0; protected baseline | None | If mutation is needed but ownership/session is uncertain, stop |
| DB | Existing container state | Start NPC DB once only if stopped; bounded SELECT readiness | Preserve running DB on timeout; no reset/restore |
| Game container | DB ready, exact component manifest and private mounts | Start NPC game container once only if stopped | No restart/recreate on uncertainty |
| Display | X processes, lock PID/liveness, socket connectivity/types/inodes | Guarded stale-file removal; same-flags Xvfb start only if absent | Live or ambiguous display is preserved |
| Native | Display proven ready, program states and reviewed manifest | Start only necessary stopped/fatal core programs once | Stop after first failure; do not launch later programs |
| Report | Current status, ports, components, protected projections | Write bounded report to explicit owned output path | Never relabel partial success as ready |

Implementation must obtain the current canonical QA ownership/lease reference and typed allowed states from Root. Its path/schema are intentionally not guessed here. Observe mode may inspect health while another owner is active; apply mode must refuse conflicts. Do not embed a historical released-lease hash as a future grant.

Use argument arrays and fixed remote operations. No shell interpolation of external input. The remote source contains a fixed SELECT readiness query and fixed own-account login-count query; credentials remain in process environment with capture-only subprocess output. Capture-only inspect/environment data must never enter exceptions, report fields or logs. All remote errors map to fixed error codes.

## Display recovery guards and timing

Before removal, prove no Xvfb/Xorg/Xwayland/X process, no live filesystem or abstract X99 socket, a numeric dead lock PID, no symlinks, correct regular-file/socket types, container-private `/tmp`, and unchanged file device/inode identities immediately before unlink. Recheck process/PID/socket liveness at the mutation boundary. If either file changes, stop. With one peer owner and these checks there is still no claim of a universal cross-process atomic guarantee; unexpected concurrent activity must fail closed.

Use the exact reviewed current NPC flags `:99 -screen 0 1024x768x16 -nolisten tcp`, not the historical legacy helper's 24-bit flag. Require both an Xvfb process and a connectable Unix socket before native starts. A process ID alone or lock file alone is insufficient.

Suggested implementation budgets for review: VM readiness 180s, strict SSH connect 5s per observation, DB readiness 60s, display readiness 10s and one native start 20s. Read-only polling is bounded and records attempts. A timed-out start is an uncertain write: perform subsequent read-only observation, return pending/unknown, and do not retry it automatically. Budgets require review against actual implementation and installed versions; they are not established performance guarantees.

## Report schema and privacy

Emit schema/version, timestamps, selected mode, target VM identity projection, current IP/hostname, fixed error codes, current component hashes, container name/state/restart policy, three program states, aggregate other-map states, DB readiness booleans, owned login-row count, display PID/socket status, tested ports and an action ledger containing enums/outcomes only.

Track newly observed running resources separately from resources this invocation definitely started. Preserve uncertain outcomes. Mark gameplay acceptance as not tested. Do not emit private key/DSN/connection string/password/token, complete configuration/environment/logs, raw SSH stderr, subprocess command representations, SQL rows other than the allowlisted readiness/count projections, or other account/player data. Bound file size, lists and diagnostic capacity; capacity exhaustion stops without replaying operations.

## Required offline checks before implementation can be reviewed for execution

| Case | Required outcome |
| --- | --- |
| Warm healthy with legitimate login/session | Observe ready; zero mutations |
| Cold approved profile | Exactly one VM start if needed, DB before game, display before native; no extra map starts |
| Observe/default mode on unhealthy VM | Diagnostics only; no starts/deletes/config writes |
| Wrong VM path/MAC, outside-subnet IP, wrong hostname or host-key mismatch | Stop before guest mutation |
| Missing refs/containers/components, altered native/config, binding mismatch | Explicit stop; no synthesis/rebind/deploy |
| Live lock PID, live X server, either live socket form, active QA conflict or nonzero/unknown owned login count | No cleanup or starts |
| Symlink, wrong file type, shared tmp, inode swap or PID reuse at guard boundary | No deletion |
| Only genuine stale private X99 files | Exactly the two unlink operations, then exact reviewed Xvfb args |
| DB query failure/recovery timeout | No game start; no credential-bearing exception output |
| Native/transport timeout after a start may have succeeded | Unknown/pending; read-only observation permitted, zero automatic replays |
| First native program fails | No later program starts; protected resources preserved |
| Repeat same operation with healthy resulting state | No additional mutation |
| Malicious input or raw diagnostic secret sentinels | No shell execution or secret in report/errors/stdout |
| Output/capacity failure | Preserve effects ledger and stop; no cleanup/restore of unrelated resources |

Use fake subprocess transports and synthetic owned temporary files for these checks. Do not call VMware, SSH, Docker, SQL, Wine or a game process from the offline suite. These tests verify control flow and negative boundaries, not actual VM/runtime readiness. A later separately reviewed runtime smoke must record actual identity, current manifests/ownership, before/after states and selected health gates.

## Rollback and recovery after partial failure

Default behavior is preserve-and-report, not automatic teardown. Never stop a preexisting VM/DB/container/program or reverse ordinary database writes. Never recreate stale display files. A future explicit stop mode is out of scope. If this invocation definitely started a resource but later failed, its ledger allows Root to decide the next action; uncertain ownership or start outcomes prohibit automatic stop/retry.

Reverting the future helper source is separate from runtime rollback and must not restart any shared MCP server. This design does not add a service, schedule, Windows startup entry or automatic restart policy.

## Basis and unresolved review inputs

The design follows the [Docker restart-policy documentation](https://docs.docker.com/engine/containers/start-containers-automatically/) and [X.Org stale-lock guidance](https://www.x.org/FAQErrorMessages/) alongside the locally verified manual recovery. It retains explicit startup rather than enabling every QA container on boot because the current environment deliberately separates profiles and map readiness.

Before coding: Root must confirm the implementation base/write set, current lease/ownership projection, reviewed component manifest storage, accepted apply invocation/identity checks, and timeout/error-report contract. Before actual execution: review exact source hashes and offline results, establish fresh runtime ownership, then authorize a bounded real smoke. All-item/map/quest/monster/pet/mount testing remains a separate gameplay coverage task owned by the existing QA/Data/Client workers; this wrapper cannot certify it.
