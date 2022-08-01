%define name    stella
%define version 6.7
%define rel     1

%define enable_sound 1
%define enable_debugger 1
%define enable_joystick 1
%define enable_cheats 1
%define enable_static 0

%define release %rel

Summary:        An Atari 2600 Video Computer System emulator
Name:           %{name}
Version:        %{version}
Release:        %{release}
Group:          Emulators
License:        GPL
URL:            https://stella-emu.github.io
Source:         %{name}-%{version}.tar.xz
BuildRoot:      %_tmppath/%name-%version-%release-root
BuildRequires:  SDL2-devel MesaGLU-devel

%description
The Atari 2600 Video Computer System (VCS), introduced in 1977, was the most
popular home video game system of the early 1980's.  This emulator will run
most Atari ROM images, so that you can play your favorite old Atari 2600 games
on your PC.

%prep

%setup -q

%build
export CXXFLAGS=$RPM_OPT_FLAGS
%configure --enable-release \
%if %enable_sound
  --enable-sound \
%else
  --disable-sound \
%endif
%if %enable_debugger
  --enable-debugger \
%else
  --disable-debugger \
%endif
%if %enable_joystick
  --enable-joystick \
%else
  --disable-joystick \
%endif
%if %enable_cheats
  --enable-cheats \
%else
  --disable-cheats \
%endif
%if %enable_static
  --enable-static \
%else
  --enable-shared \
%endif
  --docdir=%{_docdir}/stella

%make

%install
rm -rf $RPM_BUILD_ROOT

make install-strip DESTDIR=%{buildroot}
# Mandriva menu entries
install -d -m0755 %{buildroot}%{_menudir}
cat > %{buildroot}%{_menudir}/%{name} << EOF
?package(%{name}): command="stella" \
icon="stella.png" \
needs="x11" \
title="Stella" \
longtitle="A multi-platform Atari 2600 emulator" \
section="More Applications/Emulators" \
xdg="true"
EOF

%clean
rm -rf $RPM_BUILD_ROOT
rm -rf $RPM_BUILD_DIR/%{name}-%{version}

%post
%update_menus

%postun
%clean_menus

%files
%defattr(-,root,root,-)
%_bindir/*
%{_menudir}/%{name}
%{_datadir}/applications/%{name}.desktop
%_docdir/stella/*
%_datadir/icons/%{name}.png
%_datadir/icons/mini/%{name}.png
%_datadir/icons/large/%{name}.png

%changelog
* Mon Jun 13 2022 Stephen Anthony <sa666666@gmail.com> 6.7-1
- Version 6.7 release

* Tue Nov 16 2021 Stephen Anthony <sa666666@gmail.com> 6.6-1
- Version 6.6 release

* Tue Apr 20 2021 Stephen Anthony <sa666666@gmail.com> 6.5.3-1
- Version 6.5.3 release

* Thu Feb 25 2021 Stephen Anthony <sa666666@gmail.com> 6.5.2-1
- Version 6.5.2 release

* Sun Jan 24 2021 Stephen Anthony <sa666666@gmail.com> 6.5.1-1
- Version 6.5.1 release

* Sat Jan 9 2021 Stephen Anthony <sa666666@gmail.com> 6.5-1
- Version 6.5 release

* Mon Nov 2 2020 Stephen Anthony <sa666666@gmail.com> 6.4-1
- Version 6.4 release

* Wed Oct 7 2020 Stephen Anthony <sa666666@gmail.com> 6.3-1
- Version 6.3 release

* Sat Jun 20 2020 Stephen Anthony <sa666666@gmail.com> 6.2.1-1
- Version 6.2.1 release

* Sun Jun 7 2020 Stephen Anthony <sa666666@gmail.com> 6.2-1
- Version 6.2 release

* Sat Apr 25 2020 Stephen Anthony <sa666666@gmail.com> 6.1.2-1
- Version 6.1.2 release

* Sat Apr 04 2020 Stephen Anthony <sa666666@gmail.com> 6.1.1-1
- Version 6.1.1 release

* Sun Mar 22 2020 Stephen Anthony <sa666666@gmail.com> 6.1-1
- Version 6.1 release

* Fri Oct 11 2019 Stephen Anthony <sa666666@gmail.com> 6.0.2-1
- Version 6.0.2 release

* Wed Jun 5 2019 Stephen Anthony <sa666666@gmail.com> 6.0.1-1
- Version 6.0.1 release

* Sun Dec 23 2018 Stephen Anthony <sa666666@gmail.com> 6.0-1
- Version 6.0 release

* Wed Feb 21 2018 Stephen Anthony <sa666666@gmail.com> 5.1.1-1
- Version 5.1.1 release

* Sun Feb 04 2018 Stephen Anthony <sa666666@gmail.com> 5.1-1
- Version 5.1 release

* Sun Aug 20 2017 Stephen Anthony <sa666666@gmail.com> 5.0.2-1
- Version 5.0.2 release

* Sun Jul 23 2017 Stephen Anthony <sa666666@gmail.com> 5.0.1-1
- Version 5.0.1 release

* Sun Jul 16 2017 Stephen Anthony <sa666666@gmail.com> 5.0-1
- Version 5.0 release

* Mon Nov 21 2016 Stephen Anthony <sa666666@gmail.com> 4.7.3-1
- Version 4.7.3 release

* Fri Mar 25 2016 Stephen Anthony <sa666666@gmail.com> 4.7.2-1
- Version 4.7.2 release

* Sat Feb 13 2016 Stephen Anthony <sa666666@gmail.com> 4.7.1-1
- Version 4.7.1 release

* Mon Jan 25 2016 Stephen Anthony <sa666666@gmail.com> 4.7-1
- Version 4.7 release

* Wed Oct 28 2015 Stephen Anthony <sa666666@gmail.com> 4.6.7-1
- Version 4.6.7 release

* Sun Oct 11 2015 Stephen Anthony <sa666666@gmail.com> 4.6.6-1
- Version 4.6.6 release

* Sat Sep 26 2015 Stephen Anthony <sa666666@gmail.com> 4.6.5-1
- Version 4.6.5 release

* Wed Apr 22 2015 Stephen Anthony <sa666666@gmail.com> 4.6.1-1
- Version 4.6.1 release

* Sat Mar 21 2015 Stephen Anthony <sa666666@gmail.com> 4.6-1
- Version 4.6 release

* Thu Jan 1 2015 Stephen Anthony <sa666666@gmail.com> 4.5-1
- Version 4.5 release

* Tue Oct 28 2014 Stephen Anthony <sa666666@gmail.com> 4.2-1
- Version 4.2 release

* Sun Sep 14 2014 Stephen Anthony <sa666666@gmail.com> 4.1.1-1
- Version 4.1.1 release

* Mon Sep 1 2014 Stephen Anthony <sa666666@gmail.com> 4.1-1
- Version 4.1 release

* Tue Jul 1 2014 Stephen Anthony <sa666666@gmail.com> 4.0-1
- Version 4.0 release

* Mon Jan 20 2014 Stephen Anthony <sa666666@gmail.com> 3.9.3-1
- Version 3.9.3 release

* Sat Aug 31 2013 Stephen Anthony <sa666666@gmail.com> 3.9.2-1
- Version 3.9.2 release

* Wed Aug 21 2013 Stephen Anthony <sa666666@gmail.com> 3.9.1-1
- Version 3.9.1 release

* Thu Jun 27 2013 Stephen Anthony <sa666666@gmail.com> 3.9-1
- Version 3.9 release

* Sun Mar 3 2013 Stephen Anthony <sa666666@gmail.com> 3.8.1-1
- Version 3.8.1 release

* Thu Feb 21 2013 Stephen Anthony <sa666666@gmail.com> 3.8-1
- Version 3.8 release

* Sat Dec 22 2012 Stephen Anthony <sa666666@gmail.com> 3.7.5-1
- Version 3.7.5 release

* Wed Oct 31 2012 Stephen Anthony <sa666666@gmail.com> 3.7.4-1
- Version 3.7.4 release

* Fri Oct 26 2012 Stephen Anthony <sa666666@gmail.com> 3.7.3-1
- Version 3.7.3 release

* Sun Jun 10 2012 Stephen Anthony <sa666666@gmail.com> 3.7.2-1
- Version 3.7.2 release

* Fri Jun 8 2012 Stephen Anthony <sa666666@gmail.com> 3.7.1-1
- Version 3.7.1 release

* Fri Jun 1 2012 Stephen Anthony <sa666666@gmail.com> 3.7-1
- Version 3.7 release

* Fri Mar 30 2012 Stephen Anthony <sa666666@gmail.com> 3.6.1-1
- Version 3.6.1 release

* Fri Mar 16 2012 Stephen Anthony <sa666666@gmail.com> 3.6-1
- Version 3.6 release

* Sat Feb 4 2012 Stephen Anthony <sa666666@gmail.com> 3.5.5-1
- Version 3.5.5 release

* Thu Dec 29 2011 Stephen Anthony <sa666666@gmail.com> 3.5-1
- Version 3.5 release

* Sat Jun 11 2011 Stephen Anthony <sa666666@gmail.com> 3.4.1-1
- Version 3.4.1 release

* Sun May 29 2011 Stephen Anthony <sa666666@gmail.com> 3.4-1
- Version 3.4 release

* Fri Nov 12 2010 Stephen Anthony <sa666666@gmail.com> 3.3-1
- Version 3.3 release

* Wed Aug 25 2010 Stephen Anthony <sa666666@gmail.com> 3.2.1-1
- Version 3.2.1 release

* Fri Aug 20 2010 Stephen Anthony <sa666666@gmail.com> 3.2-1
- Version 3.2 release

* Mon May 3 2010 Stephen Anthony <sa666666@gmail.com> 3.1.2-1
- Version 3.1.2 release

* Mon Apr 26 2010 Stephen Anthony <sa666666@gmail.com> 3.1.1-1
- Version 3.1.1 release

* Thu Apr 22 2010 Stephen Anthony <sa666666@gmail.com> 3.1-1
- Version 3.1 release

* Fri Sep 11 2009 Stephen Anthony <sa666666@gmail.com> 3.0-1
- Version 3.0 release

* Thu Jul 4 2009 Stephen Anthony <sa666666@gmail.com> 2.8.4-1
- Version 2.8.4 release

* Thu Jun 25 2009 Stephen Anthony <sa666666@gmail.com> 2.8.3-1
- Version 2.8.3 release

* Tue Jun 23 2009 Stephen Anthony <sa666666@gmail.com> 2.8.2-1
- Version 2.8.2 release

* Fri Jun 19 2009 Stephen Anthony <sa666666@gmail.com> 2.8.1-1
- Version 2.8.1 release

* Tue Jun 9 2009 Stephen Anthony <sa666666@gmail.com> 2.8-1
- Version 2.8 release

* Tue May 1 2009 Stephen Anthony <sa666666@gmail.com> 2.7.7-1
- Version 2.7.7 release

* Tue Apr 14 2009 Stephen Anthony <sa666666@gmail.com> 2.7.6-1
- Version 2.7.6 release

* Fri Mar 27 2009 Stephen Anthony <sa666666@gmail.com> 2.7.5-1
- Version 2.7.5 release

* Mon Feb 9 2009 Stephen Anthony <sa666666@gmail.com> 2.7.3-1
- Version 2.7.3 release

* Tue Jan 27 2009 Stephen Anthony <sa666666@gmail.com> 2.7.2-1
- Version 2.7.2 release

* Mon Jan 26 2009 Stephen Anthony <sa666666@gmail.com> 2.7.1-1
- Version 2.7.1 release

* Sat Jan 17 2009 Stephen Anthony <sa666666@gmail.com> 2.7-1
- Version 2.7 release

* Thu May 22 2008 Stephen Anthony <sa666666@gmail.com> 2.6.1-1
- Version 2.6.1 release

* Fri May 16 2008 Stephen Anthony <sa666666@gmail.com> 2.6-1
- Version 2.6 release

* Wed Apr 9 2008 Stephen Anthony <sa666666@gmail.com> 2.5.1-1
- Version 2.5.1 release

* Fri Mar 28 2008 Stephen Anthony <sa666666@gmail.com> 2.5-1
- Version 2.5 release

* Mon Aug 27 2007 Stephen Anthony <sa666666@gmail.com> 2.4.1-1
- Version 2.4.1 release
