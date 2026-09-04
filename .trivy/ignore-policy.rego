package trivy

# Findings this repository cannot act on as a class, as opposed to the
# individual accepted findings in .trivyignore.yaml.
#
# A rule and not a list because these recur. Every new kernel advisory Oracle
# rates CRITICAL would otherwise block main until somebody appended another
# entry, and a gate that needs regular unblocking is a gate that gets removed.

default ignore = false

# Kernel packages in a container image.
#
# ci/graalvm is built on Oracle Linux and pulls kernel-headers in through
# glibc-devel, which native-image needs. kernel-headers is C headers compiled
# against, never executed, and a container does not boot its own kernel — it
# calls the host's. CVE-2026-31613, an out-of-bounds read in the kernel SMB
# client, is real code in the host kernel and is the host's to patch; nothing
# in this image can reach it.
#
# Alpine and distroless images carry no kernel packages, so this matches
# nothing in the other seven.
ignore {
	startswith(input.PkgName, "kernel")
}
