#/bin/bash

helm template charts/fiorali --values=charts/fiorali/values.yaml --values="charts/fiorali/${1}.yaml" > "other/scripts/tmp/${1}_debug.yaml"