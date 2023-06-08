@echo off
docker run -it --privileged --name="ksl" yukikurosawadev/ksl-cd:%1
docker stop ksl
rem docker rm ksl