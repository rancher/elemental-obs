#
# spec file for package elemental-system-agent
#
# Copyright (c) 2022 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:           elemental-system-agent
%define gitname system-agent
Version:        0.3.9
Release:        0
Summary:        Rancher system agent to apply 'plans' to a system
License:        Apache-2.0
Group:          System/Management
URL:            https://github.com/rancher/%{gitname}
Source:         %{name}-%{version}.tar.gz
Source1:        vendor.tar.gz

%if 0%{?suse_version}
BuildRequires:  golang-packaging
BuildRequires:  golang(API) >= 1.21
%{go_provides}
%else
%global goipath  github.com/rancher/system-agent
%global forgeurl https://github.com/rancher/system-agent
%global goname   %{name}
%gometa
%if (0%{?centos_version} == 800) || (0%{?rhel_version} == 800)
BuildRequires:  go1.20
%else
BuildRequires:  compiler(go-compiler)
%endif
%endif

BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
elemental-system-agent is a daemon designed to run on a system and apply
"plans" to the system. elemental-system-agent can support both local and
remote plans, and was built to be integrated with the Rancher2 project
for provisioning next-generation, CAPI driven clusters.

%prep
%setup -q
tar xf %{S:1}

%build
%if 0%{?suse_version}
%goprep .
%endif

mkdir -p bin
if [ "$(uname)" = "Linux" ]; then
    OTHER_LINKFLAGS="-extldflags -static -s"
fi


CGO_ENABLED=0 go build -ldflags "$LINKFLAGS $OTHER_LINKFLAGS" -o bin/%{name}

%install
%if 0%{?suse_version}
%goinstall
%endif

# /usr/sbin
%{__install} -d -m 755 %{buildroot}/%{_sbindir}

# elemental-system-agent
%{__install} -m 755 bin/%{name} %{buildroot}%{_sbindir}


%files
%defattr(-,root,root,-)
%doc README.md
%license LICENSE
%{_sbindir}/%{name}

%changelog
