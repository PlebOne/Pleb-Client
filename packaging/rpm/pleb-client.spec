Name:           pleb-client
Version:        0.1.0
Release:        1%{?dist}
Summary:        A native Nostr client for Linux

License:        MIT
URL:            https://pleb.one

# Pre-built binary package
AutoReqProv:    no

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia

%description
Pleb Client is a desktop Nostr client built with Qt/QML for Linux.
Features include following feed, direct messages, notifications,
profile management, and zaps via NWC.

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps

install -m 755 %{_sourcedir}/pleb_client_qt %{buildroot}/usr/bin/pleb_client_qt
install -m 644 %{_sourcedir}/pleb-client.desktop %{buildroot}/usr/share/applications/
install -m 644 %{_sourcedir}/icon-256.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/pleb-client.png
install -m 644 %{_sourcedir}/icon.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/pleb-client.svg

%files
/usr/bin/pleb_client_qt
/usr/share/applications/pleb-client.desktop
/usr/share/icons/hicolor/256x256/apps/pleb-client.png
/usr/share/icons/hicolor/scalable/apps/pleb-client.svg

%changelog
* Fri Dec 06 2024 PlebOne <contact@pleb.one> - 0.1.0-1
- Initial release
