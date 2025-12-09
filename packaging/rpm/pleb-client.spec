Name:           pleb-client
Version:        0.1.2
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
* Mon Dec 09 2024 PlebOne <contact@pleb.one> - 0.1.2-1
- Add reply/repost counts to note stats display
- Add feed filtering (Pictures, Replies, Reposts checkboxes)
- Fix login screen focus issue where window fell behind
- Real-time stats updates for visible notes
- Performance improvements for stats fetching

* Sat Dec 07 2024 PlebOne <contact@pleb.one> - 0.1.1-1
- Add Relays screen with NIP-65 relay management
- Click on user avatars/names to view profiles
- Fix profile picture loading on ProfileScreen and Sidebar
- Add loading indicators for images

* Fri Dec 06 2024 PlebOne <contact@pleb.one> - 0.1.0-1
- Initial release
