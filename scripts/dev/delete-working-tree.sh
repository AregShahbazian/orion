# Delete the CURRENT linked git worktree (git/orion-*) and drop you back into the
# main checkout (git/orion).
#
# MUST be sourced — a normal run can't cd your shell, and would leave you sitting
# in a directory it just deleted:
#
#   source scripts/dev/delete-working-tree.sh
#   .      scripts/dev/delete-working-tree.sh
#
# Refuses to run from the main orion checkout, or from a non-orion-* worktree.
# Uses plain `git worktree remove`, so it aborts if the worktree is dirty or has
# untracked files (re-run with `git worktree remove --force <path>` by hand if
# you really mean it).

# Guard against being executed instead of sourced (else `exit` kills nothing
# useful and the cd is lost). When sourced, $0 is the shell, not this file.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "delete-working-tree: must be sourced — run: source ${0}" >&2
  exit 1
fi

_dwt_run() {
  local toplevel common main cur
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "delete-working-tree: not inside a git repo" >&2
    return 1
  }
  # The main worktree is the parent of the shared git dir, regardless of $HOME.
  common="$(git rev-parse --git-common-dir 2>/dev/null)"
  main="$(cd "$(dirname "$common")" && pwd)"
  cur="$toplevel"

  if [ "$cur" = "$main" ]; then
    echo "delete-working-tree: refusing — this is the main checkout ($main)" >&2
    return 1
  fi
  case "$(basename "$cur")" in
    orion-*) : ;;
    *)
      echo "delete-working-tree: not an orion-* worktree ($cur)" >&2
      return 1
      ;;
  esac

  echo "Removing worktree: $cur"
  # Step out of the doomed dir first so we (and git) aren't standing in it.
  cd "$main" || return 1
  if git worktree remove "$cur"; then
    echo "Removed. Now in $main"
  else
    echo "delete-working-tree: 'git worktree remove' failed (dirty / untracked?" \
         "— inspect, then remove by hand with --force). You're now in $main." >&2
    return 1
  fi
}

_dwt_run
unset -f _dwt_run
