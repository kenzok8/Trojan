# trojan

[![Build](https://github.com/kenzok8/trojan/actions/workflows/build.yml/badge.svg)](https://github.com/kenzok8/trojan/actions/workflows/build.yml)

An unidentifiable mechanism that helps you bypass GFW.

Trojan features multiple protocols over `TLS` to avoid both active/passive detections and ISP `QoS` limitations.

Trojan is not a fixed program or protocol. It's an idea, an idea that imitating the most common service, to an extent that it behaves identically, could help you get across the Great FireWall permanently, without being identified ever. We are the GreatER Fire; we ship Trojan Horses.

## Documentations

An online documentation can be found in the local [`docs/`](docs) directory.  
Installation guide on various platforms can be found in the [wiki](https://github.com/kenzok8/trojan/wiki/Binary-&-Package-Distributions).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Dependencies

- [CMake](https://cmake.org/) >= 3.7.2
- [Boost](http://www.boost.org/) >= 1.66.0
- [OpenSSL](https://www.openssl.org/) >= 1.1.0
- [libmysqlclient](https://dev.mysql.com/downloads/connector/c/)

## License

[GPLv3](LICENSE)

## kenzok8 maintenance

This fork is actively maintained by kenzok8 with independent release cadence.

## Maintainer release cadence

This repository follows kenzok8 maintainer iteration releases (semantic bumps with package sync + build verification).
