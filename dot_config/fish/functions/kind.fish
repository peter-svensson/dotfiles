# # Kind load
# kind_load() {
#     local DIR=$(pwd)
#     while [ ! -z "$DIR" ] && [ ! -f "$DIR/.buildtools.yaml" ]; do
#         DIR="${DIR%\/*}"
#     done
#
#     if [ -z "${DIR}" ]; then
#         echo "No .buildtools.yaml file found"
#         return
#     fi
#
#     local REGISTRY=$(yq e '.registry.*.url' ${DIR}/.buildtools.yaml)
#     local CLUSTER=$(basename $(dirname $PWD))
#     local NAME=${IMAGE_NAME:-$(basename $PWD)}
#     local COMMIT=$(git rev-parse HEAD)
#
#     kind load --name ${CLUSTER} docker-image ${REGISTRY}/${NAME}:${COMMIT}
# }
#
# deploy_local() {
#     kind_load
#     deploy local
# }
