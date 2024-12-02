#
# spec file for package updatesparser
#
# Copyright (c) 2022 - 2023 SUSE LINUX GmbH, Nuernberg, Germany.
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

Name:           updatesparser
Version:        0.1
Release:        0
Summary:        A simple parser for updateinfo XML files
License:        Apache-2.0
Group:          System/Management
Url:            https://github.com/rancher/elemental-channels
Source:         %{name}.tar.xz

BuildRequires:  golang(API) >= 1.22
BuildRequires:  golang-packaging
BuildRequires:  xz

BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
This package provides a simple golang utility to filter and parse update info XML files

%prep
%setup -q -n %{name}

%build

make build


%install
mkdir -p %{buildroot}%{_bindir}
install -m755 build/updatesparser %{buildroot}%{_bindir}

%files
%defattr(-,root,root,-)
%license LICENSE
%{_bindir}/updatesparser

%changelog
