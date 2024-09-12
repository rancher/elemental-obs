#
# spec file for package elemental-post-build-generate-rpi-image
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

Name:           elemental-post-build-generate-rpi-image
Summary:        Post build script to generate RPi image from Elemental ISO from a container
License:        GPL-2.0-or-later
Group:          Development/Tools/Building
Version:        0.4
Release:        0
Requires:       buildah
# for truncate
Requires:       coreutils
# for mkfs.vfat
Requires:       dosfstools
# for mkfs.ext
Requires:       e2fsprogs
# for sfdisk
Requires:       util-linux
# for grub manipulation
Requires:       sed

%define post_build_dir /usr/lib/build/post_build.d

Source0:        generate-rpi-image.sh
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
An OBS post build hook that generates a RPi boot image from the Elemental ISO from a container.
The image is expected to be found at "/image/*.img".

%prep
cp %{S:0} .

%build

%install
install -D -m 755 generate-rpi-image.sh $RPM_BUILD_ROOT%{post_build_dir}/50-elemental-generate-rpi-image

%files
%defattr(-, root, root)
%dir /usr/lib/build
%dir %{post_build_dir}
%{post_build_dir}/50-elemental-generate-rpi-image


%changelog

