#!/bin/bash



# Thanks to https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

#KPI_TABLES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT tablename FROM pg_catalog.pg_tables where schemaname='public'"))
# We could read table from DB, but we need the order to be respected.
# Otherwise inserts may fail because of FK not present.
KPI_TABLES=(
 spatial_ref_sys
 django_migrations
 django_content_type
 auth_user
 auth_group
 auth_permission
 auth_group_permissions
 auth_user_groups
 auth_user_user_permissions
 constance_config
 django_celery_beat_periodictasks
 django_celery_beat_crontabschedule
 django_celery_beat_intervalschedule
 django_celery_beat_periodictask
 django_celery_beat_solarschedule
 django_admin_log
 authtoken_token
 django_digest_partialdigest
 taggit_tag
 taggit_taggeditem
 kpi_collection
 kpi_asset
 reversion_revision
 reversion_version
 kpi_assetversion
 kpi_importtask
 kpi_authorizedapplication
 kpi_taguid
 kpi_objectpermission
 kpi_assetsnapshot
 kpi_onetimeauthenticationkey
 kpi_usercollectionsubscription
 kpi_exporttask
 kpi_assetfile
 hub_sitewidemessage
 hub_configurationfile
 hub_formbuilderpreference
 hub_extrauserdetail
 oauth2_provider_application
 django_session
 oauth2_provider_accesstoken
 oauth2_provider_grant
 django_digest_usernonce
 oauth2_provider_refreshtoken
 registration_registrationprofile
 hook_hook
 hook_hooklog
)

SLEEP_TIME=0
MESSAGE="WARNING!!! This script will wipe all the data on target database:"
TARGET_DBNAME_LEN=${#KPI_POSTGRES_DB}
MESSAGE_LEN=${#MESSAGE}
LIMIT=$((MESSAGE_LEN-TARGET_DBNAME_LEN-1))

printf "╔═%s═╗\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))
printf "║ ${MESSAGE} ║\n"
printf "║ ${KPI_POSTGRES_DB} %s ║\n" $(printf ".%.0s" $(seq 1 $LIMIT))
printf "╚═%s═╝\n" $(printf "═%.0s" $(seq 1 $MESSAGE_LEN))

while true; do

    read -p "Do you want to continue [y/N]?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer Y or N.";;
    esac
done


for KPI_TABLE in "${KPI_TABLES[@]}"
do
    :
    echo "Truncating ${KPI_POSTGRES_DB}.public.${KPI_TABLE}..."
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -c "TRUNCATE TABLE ${KPI_TABLE} RESTART IDENTITY CASCADE"
    printf "\tDone!\n"
    sleep $SLEEP_TIME # Use to let us read the output if there are any errors
    echo ""
done

KPI_SEQUENCES=($(psql -U ${POSTGRES_USER} -d ${KPI_POSTGRES_DB} -t -c "SELECT c.relname FROM pg_class c WHERE c.relkind = 'S';"))

for KPI_TABLE in "${KPI_TABLES[@]}"
do
    :
    echo "Copying table ${KC_POSTGRES_DB}.public.${KPI_TABLE} to ${KPI_POSTGRES_DB}.public.${KPI_TABLE}..."
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KC_POSTGRES_DB} \
        -c "\\copy ${KPI_TABLE} to stdout" \
    | \
    psql \
        -X \
        -U ${POSTGRES_USER} \
        -h localhost \
        -d ${KPI_POSTGRES_DB} \
        -c "\\copy ${KPI_TABLE} from stdin"
    sleep $SLEEP_TIME # Use to let us read the output if there are any errors
    printf "\tDone!\n"

    SEQUENCE_NAME="${KPI_TABLE}_id_seq"
    if [ $(contains "${KPI_SEQUENCES[@]}" "${SEQUENCE_NAME}") == "y" ]; then
        echo "Updating sequence for table ${KPI_POSTGRES_DB}.public.${KPI_TABLE}..."
        psql \
            -X \
            -U ${POSTGRES_USER} \
            -h localhost \
            -d ${KPI_POSTGRES_DB} \
            -c "SELECT setval('${SEQUENCE_NAME}', (SELECT max(id) from ${KPI_TABLE}))"
        sleep $SLEEP_TIME # Use to let us read the output if there are any errors
        echo ""
    fi


done