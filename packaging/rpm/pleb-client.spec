Name:           pleb-client
Version:        0.1.0
Release:        1%{?dist}
Summary:        A native Nostr client for Linux

License:        MIT
URL:            https://pleb.one
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust cargo
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
BuildRequires:  clang-devel
BuildRequires:  openssl-devel

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       qt6-qtquickcontrols2

%description
Pleb Client is a desktop Nostr client built with Qt/QML for Linux.
Features include following feed, direct messages, notifications,
profile management, and zaps via NWC.

%prep
%autosetup

%build
cargo build --release

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps

install -m 755 target/release/pleb_client_qt %{buildroot}/usr/bin/pleb_client_qt
install -m 644 resources/pleb-client.desktop %{buildroot}/usr/share/applications/
install -m 644 resources/icons/icon-256.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/pleb-client.png
install -m 644 resources/icons/icon.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/pleb-client.svg

%files
/usr/bin/pleb_client_qt
/usr/share/applications/pleb-client.desktop
/usr/share/icons/hicolor/256x256/apps/pleb-client.png
/usr/share/icons/hicolor/scalable/apps/pleb-client.svg

%changelog
* Fri Dec 06 2024 PlebOne <contact@pleb.one> - 0.1.0-1
- Initial release
