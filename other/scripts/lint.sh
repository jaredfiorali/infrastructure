#/bin/bash

clear
for chart in charts/fiorali/*; do
  chart_name=$(basename $chart .yaml)
  # Skip: Charts.yaml, values.yaml, and templates folder
  if [ $chart == "charts/fiorali/Chart.yaml" ] || [ $chart == "charts/fiorali/values.yaml" ] || [ $chart == "charts/fiorali/templates" ]; then
    echo "Skipping $chart_name"
  else
    echo "Linting ${chart_name}"
    helm lint --quiet charts/fiorali -f charts/fiorali/values.yaml -f $chart;
    yamllint  -c other/scripts/.yamllint.yaml $chart;
    other/scripts/test-chart.sh $chart_name && yamllint  -c other/scripts/.yamllint.yaml "other/scripts/tmp/${chart_name}_debug.yaml";
  fi
done