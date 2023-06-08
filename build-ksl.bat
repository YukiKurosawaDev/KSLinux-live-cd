@echo off
cls
docker system df
docker image rm yukikurosawadev/ksl-cd:%1
rem docker builder prune -f
docker build -f=Dockerfile --tag=yukikurosawadev/ksl-cd:%1 .
docker system df