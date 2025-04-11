#/bin/bash

clear
helm template charts/fiorali --values=charts/fiorali/values.yaml --values=charts/fiorali/"$1".yaml --debug > debug.yaml