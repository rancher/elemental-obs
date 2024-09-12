#
# spec file for package elemental-post-build-extract-iso
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

Name:           elemental-post-build-extract-iso
Summary:        Post build script to extract Elemental ISO from a container
License:        GPL-2.0-or-later
Group:          Development/Tools/Building
Version:        0.4
Release:        0
Requires:       buildah

%define post_build_dir /usr/lib/build/post_build.d

Source0:        extract-iso.sh
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Am OBS post build hook that extracts the Elemental ISO from a container. The
ISO is exected to be found at "/iso/*.iso".

%prep
cp %{S:0} .

%build

%install
install -D -m 755 extract-iso.sh $RPM_BUILD_ROOT%{post_build_dir}/50-elemental-extract-iso

%files
%defattr(-, root, root)
%dir /usr/lib/build
%dir %{post_build_dir}
%{post_build_dir}/50-elemental-extract-iso

%changelog

