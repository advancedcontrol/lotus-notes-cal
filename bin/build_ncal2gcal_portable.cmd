rem build ncal2gcal portable using the ocra gem
rem installing ocra: gem install ocra
cp ncal2gcal "%appdata%\ncal2gcal_portable"
cd %appdata%
%SystemDrive%
ocra ncal2gcal_portable
pause