#generate the cpp file with the proto file

cd "/d/protobuf-3.12.0-rc-2/build_32/Debug"
rm -rf *.h
rm -rf *.cc
./protoc.exe --cpp_out=./ ServerCommon.proto
./protoc.exe --cpp_out=./ Commands.proto

mv Commands.pb.h  Commands.h
mv Commands.pb.cc Commands.cc
mv ServerCommon.pb.h  ServerCommon.h
mv ServerCommon.pb.cc ServerCommon.cc

awk '{ sub(/\<Commands.pb.h\>/,"Commands.h"); print $0 }' Commands.cc > temp.cc
rm -rf Commands.cc && mv temp.cc Commands.cc

awk '{ sub(/\<ServerCommon.pb.h\>/,"ServerCommon.h"); print $0 }' ServerCommon.cc > temp.cc
rm -rf ServerCommon.cc && mv temp.cc ServerCommon.cc

awk '{ sub(/\<ServerCommon.pb.h\>/,"ServerCommon.h"); print $0 }' Commands.h > temp.h
rm -rf Commands.h && mv temp.h Commands.h
