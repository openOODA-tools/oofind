Name:           oofind
Version:        0.1.0
Release:        1%{?dist}
Summary:        Capability-bounded file finding utility
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oofind
Source0:        oofind-linux-x86_64
BuildArch:      x86_64
Requires:       glibc

%description
oofind is a capability-bounded file finding utility written in pure
openOODA, featuring fast recursive traversal, glob matching, JSON
output streaming, and an agent-native MCP stdio surface.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oofind

%files
/usr/bin/oofind

%changelog
* Mon Oct 05 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign release: recursive traversal, glob matching, -print0, --json, MCP stdio server
