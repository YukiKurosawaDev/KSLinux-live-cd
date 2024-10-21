@echo off
docker run -it --privileged --name="ksl" -v E:\Repo\KSLinux-live-cd\iso:/opt/ksl/iso yukikurosawadev/ksl-cd:%1
docker stop ksl
docker rm ksl