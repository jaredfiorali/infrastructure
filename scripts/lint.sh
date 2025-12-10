#/bin/bash

clear
for chart in charts/fiorali/*; do
  # Skip: Charts.yaml, values.yaml, and templates folder
  if [ $chart == "charts/fiorali/Chart.yaml" ] || [ $chart == "charts/fiorali/values.yaml" ] || [ $chart == "charts/fiorali/templates" ]; then
    echo "Skipping $chart"
  else
    echo "Linting ${chart}"
    helm lint --quiet charts/fiorali -f charts/fiorali/values.yaml -f $chart;
  fi
done