# MachBatch

MachBatch is a native, CPU-first workload manager for macOS. It makes one Mac behave like a small logical compute cluster and provides a deliberately scoped Slurm-compatible command-line experience—without Linux, a virtual machine, Docker, or a root daemon.

MachBatch targets the Slurm 26.05.4 CLI contract and runs as a private, single-user cluster on macOS 13 Ventura or newer. CPU and memory are admission-control resources; logical nodes do not create additional hardware or provide container-grade isolation.

> [!IMPORTANT]
> MachBatch is under active development. Batch submission, local scheduling, execution, accounting, timeout handling, recovery foundations, and Homebrew installation work today. Interactive jobs, full process-tree cancellation, policy administration, signing, and the complete V1 Slurm option profile are not finished yet. See [Current command coverage](#current-command-coverage).

## Why MachBatch?

- Submit repeatable local jobs with familiar `sbatch` scripts.
- Keep work queued when the Mac does not have enough available CPU or memory.
- Divide one physical Mac into safe logical nodes backed by one authoritative resource ledger.
- Inspect queued and completed jobs with Slurm-style commands.
- Preserve jobs, events, accounting state, and monotonic job IDs in SQLite.
- Run natively on Apple Silicon and Intel Macs supported by macOS 13 or newer.
- Reject unsupported options instead of accepting and silently ignoring them.

## Requirements

- macOS 13 Ventura or newer
- Apple Silicon (`arm64`) or Intel (`x86_64`)
- The system SQLite library included with macOS

MachBatch does not require a database server, Docker, a virtual machine, or root privileges for normal operation.

The current precompiled Homebrew bottle is tested on Apple Silicon with macOS 26 and is usable on newer compatible macOS releases. Other supported Macs may build the formula from source until additional native bottles are published. Source builds require Xcode 26 or another Swift 6.2-compatible toolchain.

## Install with Homebrew

Homebrew is the recommended installation path:

```bash
brew install kodlabs-in/tap/machbatch
```

Homebrew installs `machbatch`, `machbatchd`, and all eleven Slurm-compatible command links. Verify the installation:

```bash
machbatch --version
machbatch doctor
sinfo
```

Upgrade through Homebrew:

```bash
brew update
brew upgrade machbatch
```

Uninstalling removes Homebrew-managed commands but preserves configuration, spool files, and job history under `~/Library/Application Support/MachBatch`:

```bash
brew uninstall machbatch
```

## Install from source

For development or platforms without a matching bottle, build MachBatch with Swift Package Manager:

```bash
git clone https://github.com/kodlabs-in/machbatch.git
cd machbatch
swift build -c release
```

Install the two executables and Slurm-compatible command links into a user-owned directory:

```bash
install_root="$HOME/.local/bin"
mkdir -p "$install_root"
install -m 755 .build/release/machbatch "$install_root/machbatch"
install -m 755 .build/release/machbatchd "$install_root/machbatchd"

for command in sinfo squeue sbatch srun salloc scancel sacct sstat sprio scontrol sacctmgr; do
  ln -sf machbatch "$install_root/$command"
done
```

Make sure the installation directory is on `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add that export to `~/.zshrc` to keep it across terminal sessions.

You can also use the multicall binary without creating links:

```bash
machbatch sinfo
machbatch sbatch --wrap '/usr/bin/true'
```

## Quick start

Inspect the automatically generated local cluster:

```bash
sinfo
```

Submit a command:

```bash
sbatch \
  --job-name hello \
  --cpus-per-task 1 \
  --mem 256M \
  --time 00:01:00 \
  --wrap 'printf "hello from job $SLURM_JOB_ID\n"'
```

The development controller currently performs one scheduling pass when invoked:

```bash
machbatchd --once
```

Inspect active and historical jobs:

```bash
squeue
sacct --jobs 1
```

Unless overridden, batch output is written to `slurm-%j.out` in the submission directory, where `%j` is replaced by the job ID.

## Submit a batch script

Create `example.sbatch`:

```bash
#!/bin/zsh
#SBATCH --job-name=example
#SBATCH --partition=local
#SBATCH --cpus-per-task=2
#SBATCH --mem=512M
#SBATCH --time=00:05:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

printf 'job=%s user=%s partition=%s\n' \
  "$SLURM_JOB_ID" \
  "$SLURM_JOB_USER" \
  "$SLURM_JOB_PARTITION"
```

Submit and execute it:

```bash
sbatch example.sbatch
squeue
machbatchd --once
sacct --jobs 1
```

MachBatch copies submitted scripts into its private spool before returning a job ID. Editing or deleting the original script after submission does not change the queued job.

Command-line options override matching `#SBATCH` directives:

```bash
sbatch --job-name=override --mem=1G example.sbatch
```

## Supported `sbatch` options

The currently executable batch profile is:

| Option | Purpose |
| --- | --- |
| `--wrap <command>` | Submit an inline shell command |
| `-J`, `--job-name <name>` | Set the job name |
| `-p`, `--partition <name>` | Select a partition |
| `-c`, `--cpus-per-task <count>` | Request CPU admission slots |
| `--mem <size>` | Request memory, such as `256M` or `2G` |
| `-t`, `--time <duration>` | Set the wall-time limit |
| `-o`, `--output <path>` | Set the stdout path and replacement pattern |
| `-e`, `--error <path>` | Set a separate stderr path |
| `-D`, `--chdir <path>` | Set the execution working directory |
| `--export <specification>` | Select or assign persisted environment variables |
| `--parsable` | Print only the submitted job ID |
| `--help` | Show the supported command surface |
| `--version` | Show MachBatch and Slurm compatibility identity |

Supported wall-time forms include `minutes`, `minutes:seconds`, `hours:minutes:seconds`, and `days-hours:minutes:seconds`.

Environment examples:

```bash
# Preserve the complete submission environment (the default).
sbatch --wrap '/usr/bin/env'

# Start with an empty submitted environment and add explicit values.
sbatch --export=NONE,MODE=release --wrap '/usr/bin/printenv MODE'

# Preserve everything and override one value.
sbatch --export=ALL,MODE=debug --wrap '/usr/bin/printenv MODE'
```

Persisted environment data is stored under a user-private data root. Environment values are not printed by routine MachBatch logging.

## Current command coverage

MachBatch reserves the exact 11 V1 Slurm command names, but only advertises options with implemented behavior.

| Command | Current status |
| --- | --- |
| `sinfo` | Automatic local-cluster and logical-node summary |
| `squeue` | Active job summary with Slurm state abbreviations |
| `sbatch` | Script and `--wrap` submission using the option profile above |
| `scancel` | Cancellation of pending jobs by ID |
| `sacct` | Basic current and completed job history; supports `-j`/`--jobs` |
| `srun` | Identity, help, and version surface only |
| `salloc` | Identity, help, and version surface only |
| `sstat` | Identity, help, and version surface only |
| `sprio` | Identity, help, and version surface only |
| `scontrol` | Identity, help, and version surface only |
| `sacctmgr` | Identity, help, and version surface only |

An unsupported option exits unsuccessfully before creating or mutating a job.

## Diagnostics

Run the product-specific health check:

```bash
machbatch doctor
```

It verifies SQLite integrity and reports the detected architecture, active processor count, and physical memory.

## Data and privacy

The default data root is:

```text
~/Library/Application Support/MachBatch/
  backups/
  config/
  database/
  run/
  spool/
```

Directories are created with user-only permissions. For development, testing, or an isolated cluster, override the root:

```bash
export MACHBATCH_DATA_DIR="$PWD/.machbatch-data"
```

MachBatch executes commands as the current macOS user. It is not a sandbox for hostile programs and does not claim Linux cgroup-grade containment.

## Architecture

The Swift package separates domain and platform responsibilities:

```text
CLI / ControllerDaemon
        │
        ├── Controller ── Scheduler ── PriorityEngine
        ├── Executor ──── CProcessShim
        ├── Persistence ─ CSQLite
        ├── ResourceProbe
        ├── Compatibility
        ├── Config
        └── ClusterCore
```

SQLite runs in WAL mode with foreign keys enabled. Job transitions are validated and persisted as events. One physical resource ledger remains authoritative even when the Mac is represented by several logical nodes.

## Development

Build and run all tests:

```bash
swift build
swift test
```

Apply formatting and run the repository's strict lint and complexity gates:

```bash
swift-format format --in-place --recursive Sources Tests Package.swift
swiftlint lint --no-cache --strict
```

The test suite is divided by responsibility:

```text
Tests/
  Unit/                 parsers, state machines, priority, resources, scheduling
  Integration/          SQLite, controller, execution, environment, timeouts
  CompatibilityGolden/  compatibility manifest and rejection behavior
  CrashRecovery/        interrupted-job reconciliation
  Packaging/            command-line end-to-end flows
```

Development follows red-green-refactor TDD. New command options must include tests for stdout, stderr, exit status, state changes, and side effects before they are added to the compatibility manifest.

## Compatibility and limitations

- The compatibility reference is Slurm 26.05.4.
- MachBatch is an independent implementation and is not affiliated with SchedMD.
- V1 is a single-user, single-Mac cluster.
- GPU and accelerator scheduling are intentionally excluded from V1.
- CPU requests are scheduler admission slots, not hard core affinity.
- Memory reservations are enforced on a best-effort basis with public macOS facilities.
- A sleeping Mac may suspend running work; wall-clock deadlines are reconciled after execution resumes.
- The current development daemon performs one scheduling pass and is not yet the final LaunchAgent-backed controller service.

## Project status

Completed foundations include configuration discovery, resource probing, logical nodes, SQLite persistence, job lifecycle validation, priority/FIFO scheduling, basic backfill, immutable script spooling, environment persistence, output routing, wall-time termination, accounting views, restart recovery, and health diagnostics.

Before a stable V1 release, MachBatch still requires the Unix-socket controller protocol, long-running LaunchAgent operation, process-session supervision, running-job cancellation, interactive PTY execution, fully wired arrays and dependencies, QOS/account administration, complete reporting commands, reference-generated golden fixtures, additional Homebrew bottle coverage, signing, notarization, and real Intel hardware validation.

## License

MachBatch is available under the [MIT License](LICENSE).
