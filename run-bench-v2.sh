#!/bin/bash

source run-library.sh

manifest="conf/contperf/manifest.zip"
do="Default Organization"
dl="Default Location"
###registrations_per_docker_hosts=10
registrations_per_docker_hosts=5
registrations_iterations=20
###wait_interval=100
wait_interval=10

opts="--forks 100 -i conf/contperf/inventory.ini --private-key conf/contperf/id_rsa_perf"
opts_adhoc="$opts --user root"


log "===== Checking environment ====="
a 00-info-rpm-qa.log satellite6 -m "shell" -a "rpm -qa | sort"
a 00-info-hostname.log satellite6 -m "shell" -a "hostname"
a 00-check-ping-sat.log docker-hosts -m "shell" -a "ping -c 3 {{ groups['satellite6']|first }}"
a 00-check-hammer-ping.log satellite6 -m "shell" -a "! ( hammer $hammer_opts ping | grep 'Status:' | grep -v 'ok$' )"
ap 00-recreate-containers.log playbooks/docker/docker-tierdown.yaml playbooks/docker/docker-tierup.yaml
ap 00-recreate-client-scripts.log playbooks/satellite/client-scripts.yaml
ap 00-remove-hosts-if-any.log playbooks/satellite/satellite-remove-hosts.yaml
a 00-satellite-drop-caches.log -m shell -a "katello-service stop; sync; echo 3 > /proc/sys/vm/drop_caches; katello-service start" satellite6
s $( expr 3 \* $wait_interval )
set +e


log "===== Prepare for Red Hat content ====="
h 00-ensure-loc-in-org.log "organization add-location --name 'Default Organization' --location 'Default Location'"
#h 00-set-local-cdn-mirror.log "organization update --name 'Default Organization' --redhat-repository-url 'http://localhost/pub/'"
a 00-manifest-deploy.log -m copy -a "src=$manifest dest=/root/manifest-auto.zip force=yes" satellite6
count=5
for i in $( seq $count ); do
    h 01-manifest-upload-$i.log "subscription upload --file '/root/manifest-auto.zip' --organization '$do'"
    s $( expr $wait_interval / 3 )
    if [ $i -lt $count ]; then
        h 02-manifest-delete-$i.log "subscription delete-manifest --organization '$do'"
        s $( expr $wait_interval / 3 )
    fi
done
h 03-manifest-refresh.log "subscription refresh-manifest --organization '$do'"
s $wait_interval


###log "===== Sync from mirror ====="
###h 10-reposet-enable-rhel7.log  "repository-set enable --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)' --releasever '7Server' --basearch 'x86_64'"
###h 10-reposet-enable-rhel6.log  "repository-set enable --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 6 Server (RPMs)' --releasever '6Server' --basearch 'x86_64'"
###h 10-reposet-enable-rhel7optional.log "repository-set enable --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server - Optional (RPMs)' --releasever '7Server' --basearch 'x86_64'"
###h 11-repo-immediate-rhel7.log "repository update --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server' --download-policy 'immediate'"
###h 12-repo-sync-rhel7.log "repository synchronize --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server'"
###s $wait_interval
###h 12-repo-sync-rhel6.log "repository synchronize --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 6 Server RPMs x86_64 6Server'"
###s $wait_interval
###h 12-repo-sync-rhel7optional.log "repository synchronize --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server - Optional RPMs x86_64 7Server'"
###s $wait_interval
###
###
###log "===== Publish and promote big CV ====="
###h 20-cv-create-all.log "content-view create --organization '$do' --product 'Red Hat Enterprise Linux Server' --repositories 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server','Red Hat Enterprise Linux 6 Server RPMs x86_64 6Server','Red Hat Enterprise Linux 7 Server - Optional RPMs x86_64 7Server' --name 'BenchContentView'"
###h 21-cv-all-publish.log "content-view publish --organization '$do' --name 'BenchContentView'"
###s $wait_interval
###h 22-le-create-1.log "lifecycle-environment create --organization '$do' --prior 'Library' --name 'BenchLifeEnvAAA'"
###h 22-le-create-2.log "lifecycle-environment create --organization '$do' --prior 'BenchLifeEnvAAA' --name 'BenchLifeEnvBBB'"
###h 22-le-create-3.log "lifecycle-environment create --organization '$do' --prior 'BenchLifeEnvBBB' --name 'BenchLifeEnvCCC'"
###h 23-cv-all-promote-1.log "content-view version promote --organization 'Default Organization' --content-view 'BenchContentView' --to-lifecycle-environment 'Library' --to-lifecycle-environment 'BenchLifeEnvAAA'"
###s $wait_interval
###h 23-cv-all-promote-2.log "content-view version promote --organization 'Default Organization' --content-view 'BenchContentView' --to-lifecycle-environment 'BenchLifeEnvAAA' --to-lifecycle-environment 'BenchLifeEnvBBB'"
###s $wait_interval
###h 23-cv-all-promote-3.log "content-view version promote --organization 'Default Organization' --content-view 'BenchContentView' --to-lifecycle-environment 'BenchLifeEnvBBB' --to-lifecycle-environment 'BenchLifeEnvCCC'"
###s $wait_interval
###
###
###log "===== Publish and promote filtered CV ====="
###h 30-cv-create-filtered.log "content-view create --organization '$do' --product 'Red Hat Enterprise Linux Server' --repositories 'Red Hat Enterprise Linux 6 Server RPMs x86_64 6Server' --name 'BenchFilteredContentView'"
###h 31-filter-create-1.log "content-view filter create --organization '$do' --type erratum --inclusion true --content-view BenchFilteredContentView --name BenchFilterAAA"
###h 31-filter-create-2.log "content-view filter create --organization '$do' --type erratum --inclusion true --content-view BenchFilteredContentView --name BenchFilterBBB"
###h 32-rule-create-1.log "content-view filter rule create --content-view BenchFilteredContentView --content-view-filter BenchFilterAAA --date-type 'issued' --start-date 2016-01-01 --end-date 2017-10-01 --organization '$do' --types enhancement,bugfix,security"
###h 32-rule-create-2.log "content-view filter rule create --content-view BenchFilteredContentView --content-view-filter BenchFilterBBB --date-type 'updated' --start-date 2016-01-01 --end-date 2018-01-01 --organization '$do' --types security"
###h 33-cv-filtered-publish.log "content-view publish --organization '$do' --name 'BenchFilteredContentView'"
###s $wait_interval


#log "===== Sync non-EUS from CDN (do not measure becasue of unpredictable network latency) ====="
#h 00b-set-cdn-stage.log "organization update --name 'Default Organization' --redhat-repository-url 'http://cdn.stage.redhat.com/'"
#h 10b-reposet-enable-rhel7.log  "repository-set enable --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server (RPMs)' --releasever '7Server' --basearch 'x86_64:'"
#h 10b-reposet-enable-rhel6.log  "repository-set enable --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 6 Server (RPMs)' --releasever '6Server' --basearch 'x86_64'"
#h 10b-reposet-enable-rhel7optional.log "repository-set enable --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server - Optional (RPMs)' --releasever '7Server' --basearch 'x86_64'"
#h 12b-repo-sync-rhel7.log "repository synchronize --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server RPMs x86_64 7Server'" &
#h 12b-repo-sync-rhel6.log "repository synchronize --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 6 Server RPMs x86_64 6Server'" &
#h 12b-repo-sync-rhel7optional.log "repository synchronize --organization '$do' --product 'Red Hat Enterprise Linux Server' --name 'Red Hat Enterprise Linux 7 Server - Optional RPMs x86_64 7Server'" &
#wait
#s $wait_interval


log "===== Sync Tools repo we will need ====="
h product-create.log "product create --organization '$do' --name MyProduct"
h repository-create-sat-tools.log "repository create --organization '$do' --product MyProduct --name MyRepo --content-type yum --url 'http://sat-r220-02.lab.eng.rdu2.redhat.com/pulp/repos/Sat6-CI/QA/Tools_6_3_with_RHEL7_Server/custom/Satellite_Tools_6_3_Composes/Satellite_Tools_x86_64/'"
h repository-create-puppet-upgrade.log "repository create --organization '$do' --product MyProduct --name MyRepo2 --content-type yum --url 'http://sat-r220-02.lab.eng.rdu2.redhat.com/pulp/repos/Sat6-CI/QA/Tools_6_3_with_RHEL7_Server/custom/Satellite_Tools_6_3_Composes/Satellite_Tools_Puppet_4_6_3_RHEL7_x86_64/'"
h repository-sync-sat-tools.log "repository synchronize --organization '$do' --product MyProduct --name MyRepo"
h repository-sync-puppet-upgrade.log "repository synchronize --organization '$do' --product MyProduct --name MyRepo2"


log "===== Register ====="
h 40-get-os-title.log "os info --id 1"
os_title=$( grep '^Title' $logs/40-get-os-title.log | sed 's/^.*:\s\+\(.*\)$/\1/' )
h 41-hostgroup-create.log "hostgroup create --content-view 'Default Organization View' --lifecycle-environment Library --name HostGroup --query-organization '$do'"
h 42-domain-create.log "domain create --name example.com --organizations '$do'"
h 42-domain-update.log "domain update --name example.com --organizations '$do' --locations '$dl'"
h 43-ak-create.log "activation-key create --content-view 'Default Organization View' --lifecycle-environment Library --name ActivationKey --organization '$do'"
h subs-list-tools.log "--csv subscription list --organization '$do' --search 'name = MyProduct'"
tools_subs_id=$( tail -n 1 $logs/subs-list-tools.log | cut -d ',' -f 1 )
h ak-add-subs.log "activation-key add-subscription --organization '$do' --name ActivationKey --subscription-id '$tools_subs_id'"
for i in $( seq $registrations_iterations ); do
    ap 44-register-$i.log playbooks/tests/registrations.yaml -e "size=$registrations_per_docker_hosts tags=untagged,REG,REM bootstrap_operatingsystem='$os_title' bootstrap_activationkey='ActivationKey' bootstrap_hostgroup='HostGroup' grepper='Register'"
    s $wait_interval
done


log "===== Remote execution ====="
h 50-rex-set-via-ip.log "settings set --name remote_execution_connect_by_ip --value true"
a 51-rex-cleanup-know_hosts.log satellite6 -m "shell" -a "rm -rf /usr/share/foreman-proxy/.ssh/known_hosts*"
h 52-rex-date.log "job-invocation create --inputs \"command='date'\" --job-template 'Run Command - SSH Default' --search-query 'name ~ container'"
s $wait_interval
h 53-rex-sm-facts-update.log "job-invocation create --inputs \"command='subscription-manager facts --update'\" --job-template 'Run Command - SSH Default' --search-query 'name ~ container'"
s $wait_interval
h 54-rex-katello-package-upload.log "job-invocation create --inputs \"command='katello-package-upload --force'\" --job-template 'Run Command - SSH Default' --search-query 'name ~ container'"
s $wait_interval


log "===== Preparing Puppet environment ====="
ap satellite-puppet-single-cv.log playbooks/tests/puppet-single-setup.yaml &
ap satellite-puppet-big-cv.log playbooks/tests/puppet-big-setup.yaml &
a clear-used-containers-counter.log -m shell -a "echo 0 >/root/container-used-count" docker-hosts &
wait
s $wait_interval


log "===== Apply one module with different concurency ====="
for concurency in 5 15 30; do
    ap $concurency-PuppetOne.log playbooks/tests/puppet-big-test.yaml --tags SINGLE -e "size=$concurency"
    log "$( ./reg-average.sh RegisterPuppet $logs/$concurency-PuppetOne.log | tail -n 1 )"
    log "$( ./reg-average.sh SetupPuppet $logs/$concurency-PuppetOne.log | tail -n 1 )"
    log "$( ./reg-average.sh PickupPuppet $logs/$concurency-PuppetOne.log | tail -n 1 )"
    s $wait_interval
done


log "===== Apply bunch of modules with different concurency ====="
for concurency in 2 6 10 14 18; do
    ap $concurency-PuppetBunch.log playbooks/tests/puppet-big-test.yaml --tags BUNCH -e "size=$concurency"
    log "$( ./reg-average.sh RegisterPuppet $logs/$concurency-PuppetBunch.log | tail -n 1 )"
    log "$( ./reg-average.sh SetupPuppet $logs/$concurency-PuppetBunch.log | tail -n 1 )"
    log "$( ./reg-average.sh PickupPuppet $logs/$concurency-PuppetBunch.log | tail -n 1 )"
    s $wait_interval
done


function table_row() {
    local identifier="/$( echo "$1" | sed 's/\./\./g' ),"
    local description="$2"
    export IFS=$'\n'
    local count=0
    local sum=0
    local note=""
    for row in $( grep "$identifier" $logs/measurement.log ); do
        local rc="$( echo "$row" | cut -d ',' -f 3 )"
        if [ "$rc" -ne 0 ]; then
            echo "ERROR: Row '$row' have non-zero return code. Not considering it when counting duration :-(" >&2
            continue
        fi
        if echo "$identifier" | grep --quiet -- "-register-"; then
            local log="$( echo "$row" | cut -d ',' -f 2 )"
            local out=$( ./reg-average.sh "Register" "$log" | grep '^Register in ' | tail -n 1 )
            local passed=$( echo "$out" | cut -d ' ' -f 6 )
            [ -z "$note" ] && note="Number of passed regs:"
            local note="$note $passed"
            local diff=$( echo "$out" | cut -d ' ' -f 8 )
            let sum+=$diff
            let count+=1
        else
            local start="$( echo "$row" | cut -d ',' -f 4 )"
            local end="$( echo "$row" | cut -d ',' -f 5 )"
            let sum+=$( expr "$end" - "$start" )
            let count+=1
        fi
    done
    if [ "$count" -eq 0 ]; then
        local avg="N/A"
    else
        local avg=$( echo "scale=2; $sum / $count" | bc )
    fi
    echo -e "$description\t$avg\t$note"
}

log "===== Formatting results ====="
table_row "01-manifest-upload-[0-9]\+.log" "Manifest upload"
table_row "12-repo-sync-rhel7.log" "Sync RHEL7 (immediate)"
table_row "12-repo-sync-rhel6.log" "Sync RHEL6 (on-demand)"
table_row "12-repo-sync-rhel7optional.log" "Sync RHEL7 Optional (on-demand)"
table_row "21-cv-all-publish.log" "Publish big CV"
table_row "23-cv-all-promote-[0-9]\+.log" "Promote big CV"
table_row "33-cv-filtered-publish.log" "Publish smaller filtered CV"
table_row "44-register-[0-9]\+.log" "Register bunch of containers"
table_row "52-rex-date.log" "ReX 'date' on all containers"
table_row "53-rex-sm-facts-update.log" "ReX 'subscription-manager facts --update' on all containers"
table_row "54-rex-katello-package-upload.log" "ReX 'katello-package-upload --force' on all containers"