# Alephino
# - ...






echo "===== Alephino zusammenführen ====="
date
zip -j${workspace}/${date}/alephino.zip${workspace}/${date}/riesa.tsv${workspace}/${date}/leipzig.tsv
openrefine/openrefine-client -P ${port} --create${workspace}/${date}/alephino.zip --format=tsv --encoding=UTF-8 --includeFileSources=true --projectName=alephino
openrefine/openrefine-client -P ${port} --export --output${workspace}/${date}/alephino.tsv alephino
