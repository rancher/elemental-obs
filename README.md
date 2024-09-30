# Elemental OBS

This repository includes the Elemental project sources to build in Open Build Service (OBS).
Different Elemental OBS projects are mapped to brances in this repository, e.g. `dev` branch includes
the sources of the development project in OBS.

## Automation notes

`main` branch includes scripts and setups to automate the generation of RPM, chart and container sources
from the devoted upstream repositories. In particular this repository essentially gathers and manages the
sources from [rancher/elemental](https://github.com/rancher/elemental),
[rancher/elemental-operator](https://github.com/rancher/elemental-operator),
[rancher/elemental-toolkit](https://github.com/rancher/elemental-toolkit) and
[rancher/elemental-channels](https://github.com/rancher/elemental-channels), in addition of the sources of other
packages that SUSE specific and only living in OBS.

There is a sources refresh workflow that is executed periodically to refresh sources. This is configured with the
`config.yaml` file in `main` branch. This yaml file is used to define the upstream repositories that are used to
refresh a local branch. See the example below:


```yaml
dev:
- repo: rancher/elemental-toolkit
  branch: main
  parseVersion: patch
  versionOffset: yes
```

The above yaml states to updates source of the local `dev` branch with the sources of the upstream
`rancher/elemental-toolkit` repository and `main` branch. In addition sets to compute the version from
up to the patch level from the upstream checkout tag and append a semver compliant commit suffix to
the version.


### Convention notes

The scripts from this repository expect that all upstream repositories are organized consistently to provide
OBS build recipes for three different types of artifacts: RPMs, container images and Helm charts. The expectation
is that the required build recipes are defined inside the `.obs/<recipetype>/<obs_package>` subfolder of
the repository root. `<recipetype>` has to be one of the following: `chartfile`, `dockerfile` or `specfile`; to
define which type or package are we dealing with. `<obs_package>` is a directory that matches the name of the
OBS package. 

As an example `rancher/elemental-toolkit` RPM's specfile should be defined in `.obs/specfile/elemental-toolkit/elemental-toolkit.spec`.

Finally, for RPMs there is also the convention for having these macros defined in spec:

```
%define commit _replaceme_
%define c_date _replaceme_
```

Where `_replaceme_` is just a placeholder that get replaced together with the package version by the automation
scripts. This is essentially an effort to define some conventions across Elemental git repositories to facilitate
the conversion to OBS ready sources.
