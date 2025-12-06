# Pleb Client

A native Nostr client for Linux built with Qt/QML and Rust.

## Features

- **Feeds**: Following, replies, and global timeline
- **Direct Messages**: NIP-04 encrypted conversations
- **Notifications**: Mentions, replies, zaps, and follows
- **Profiles**: View and edit your profile
- **Zaps**: Send zaps via Nostr Wallet Connect (NWC)
- **Media**: Embedded images and video playback
- **Keyboard Navigation**: Navigate feeds with j/k keys

## Installation

### Binary

Download the latest release from the [releases page](https://github.com/PlebOne/Pleb-Client/releases).

**Tarball**
```bash
tar xzf pleb-client-0.1.0-linux-x86_64.tar.gz
./pleb_client_qt
```

**Debian/Ubuntu**
```bash
sudo dpkg -i pleb-client_0.1.0_amd64.deb
```

**Fedora/RHEL**
```bash
sudo dnf install pleb-client-0.1.0-1.fc43.x86_64.rpm
```

**Flatpak**
```bash
flatpak install pleb-client-0.1.0.flatpak
```

### Building from Source

Requirements:
- Rust 1.70+
- Qt 6.x development libraries
- Clang/LLVM

```bash
git clone https://github.com/PlebOne/Pleb-Client.git
cd Pleb-Client
cargo build --release
./target/release/pleb_client_qt
```

#### Fedora Build Dependencies

```bash
sudo dnf install qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel clang-devel
```

#### Ubuntu Build Dependencies

```bash
sudo apt install qt6-base-dev qt6-declarative-dev qt6-multimedia-dev libclang-dev
```

## Usage

### Login

Enter your nsec (private key) and set a password to encrypt it locally. The key is stored in your system keyring.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| j / Down | Next post |
| k / Up | Previous post |
| Enter | Open thread |
| Escape | Back |
| r | Refresh feed |
| n | New post |
| ? | Show shortcuts |

### Wallet Connect

To enable zaps, go to Settings and paste your NWC connection string from a compatible wallet (Alby, Mutiny, etc).

## Configuration

Config files are stored in:
- `~/.config/pleb-client/` (settings)
- `~/.local/share/pleb-client/` (database)

## Links

- Website: https://pleb.one
- Bug Reports: https://pleb.one/projects.html?id=e9ce79cf-6f96-498e-83fa-41f55a01f7aa
- Donations: https://pleb.one/donations.html

## License

MIT
