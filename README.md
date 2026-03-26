<div align="center">

# asdf-saya [![Build](https://github.com/dojoengine/asdf-saya/actions/workflows/build.yml/badge.svg)](https://github.com/dojoengine/asdf-saya/actions/workflows/build.yml) [![Lint](https://github.com/dojoengine/asdf-saya/actions/workflows/lint.yml/badge.svg)](https://github.com/dojoengine/asdf-saya/actions/workflows/lint.yml)

[saya](https://github.com/dojoengine/saya) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`, `unzip` and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).

# Install

Plugin:

```shell
asdf plugin add saya
# or
asdf plugin add saya https://github.com/dojoengine/asdf-saya.git
```

saya:

```shell
# Show all installable versions
asdf list all saya

# Install specific version
asdf install saya latest

# Set a version globally (on your ~/.tool-versions file)
asdf global saya latest
```

This installs three commands:

| Command | Description |
|---------|-------------|
| `saya` | Persistent settlement daemon (STARK proof via Atlantic, or TEE mode) |
| `saya-ops` | Ops utilities — Piltover contract deployment and management |
| `saya-tee` | TEE settlement daemon (AMD SEV-SNP attestation → SP1 proof) |

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/dojoengine/asdf-saya/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [dojoengine](https://github.com/dojoengine/)
