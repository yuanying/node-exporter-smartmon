#!/bin/bash
# Script informed by the collectd monitoring script for smartmontools (using smartctl)
# by Samuel B. <samuel_._behan_(at)_dob_._sk> (c) 2012
# source at: http://devel.dob.sk/collectd-scripts/

# TODO: This probably needs to be a little more complex.  The raw numbers can have more
#       data in them than you'd think.
#       http://arstechnica.com/civis/viewtopic.php?p=22062211

# Formatting done via shfmt -i 2
# https://github.com/mvdan/sh

parse_smartctl_attributes_awk="$(
  cat <<'SMARTCTLAWK'
$1 ~ /^ *[0-9]+$/ && $2 ~ /^[a-zA-Z0-9_-]+$/ {
  gsub(/-/, "_");
  printf "%s_value{%s,smart_id=\"%s\"} %d\n", $2, labels, $1, $4
  printf "%s_worst{%s,smart_id=\"%s\"} %d\n", $2, labels, $1, $5
  printf "%s_threshold{%s,smart_id=\"%s\"} %d\n", $2, labels, $1, $6
  printf "%s_raw_value{%s,smart_id=\"%s\"} %e\n", $2, labels, $1, $10
}
SMARTCTLAWK
)"

smartmon_attrs="$(
  cat <<'SMARTMONATTRS'
airflow_temperature_cel
command_timeout
current_pending_sector
end_to_end_error
erase_fail_count
g_sense_error_rate
hardware_ecc_recovered
host_reads_32mib
host_reads_mib
host_writes_32mib
host_writes_mib
load_cycle_count
media_wearout_indicator
nand_writes_1gib
offline_uncorrectable
power_cycle_count
power_on_hours
program_fail_cnt_total
program_fail_count
raw_read_error_rate
reallocated_event_count
reallocated_sector_ct
reported_uncorrect
runtime_bad_block
sata_downshift_count
seek_error_rate
spin_retry_count
spin_up_time
start_stop_count
temperature_case
temperature_celsius
temperature_internal
total_lbas_read
total_lbas_written
udma_crc_error_count
unsafe_shutdown_count
unused_rsvd_blk_cnt_tot
wear_leveling_count
workld_host_reads_perc
workld_media_wear_indic
workload_minutes
SMARTMONATTRS
)"
smartmon_attrs="$(echo "${smartmon_attrs}" | xargs | tr ' ' '|')"

parse_smartctl_attributes() {
  local disk="$1"
  local disk_type="$2"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""
  sed 's/^ \+//g' |
    awk -v labels="${labels}" "${parse_smartctl_attributes_awk}" 2>/dev/null |
    tr '[:upper:]' '[:lower:]' |
    grep -E "(${smartmon_attrs})"
}

parse_smartctl_scsi_attributes() {
  local disk="$1"
  local disk_type="$2"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""
  while read -r line; do
    attr_type="$(echo "${line}" | tr '=' ':' | cut -f1 -d: | sed 's/^ \+//g' | tr ' ' '_')"
    attr_value="$(echo "${line}" | tr '=' ':' | cut -f2 -d: | sed 's/^ \+//g')"
    case "${attr_type}" in
    number_of_hours_powered_up_) power_on="$(echo "${attr_value}" | awk '{ printf "%e\n", $1 }')" ;;
    Current_Drive_Temperature) temp_cel="$(echo "${attr_value}" | cut -f1 -d' ' | awk '{ printf "%e\n", $1 }')" ;;
    Blocks_sent_to_initiator_) lbas_read="$(echo "${attr_value}" | awk '{ printf "%e\n", $1 }')" ;;
    Blocks_received_from_initiator_) lbas_written="$(echo "${attr_value}" | awk '{ printf "%e\n", $1 }')" ;;
    Accumulated_start-stop_cycles) power_cycle="$(echo "${attr_value}" | awk '{ printf "%e\n", $1 }')" ;;
    Elements_in_grown_defect_list) grown_defects="$(echo "${attr_value}" | awk '{ printf "%e\n", $1 }')" ;;
    esac
  done
  [ -n "$power_on" ] && echo "power_on_hours_raw_value{${labels},smart_id=\"9\"} ${power_on}"
  [ -n "$temp_cel" ] && echo "temperature_celsius_raw_value{${labels},smart_id=\"194\"} ${temp_cel}"
  [ -n "$lbas_read" ] && echo "total_lbas_read_raw_value{${labels},smart_id=\"242\"} ${lbas_read}"
  [ -n "$lbas_written" ] && echo "total_lbas_written_raw_value{${labels},smart_id=\"242\"} ${lbas_written}"
  [ -n "$power_cycle" ] && echo "power_cycle_count_raw_value{${labels},smart_id=\"12\"} ${power_cycle}"
  [ -n "$grown_defects" ] && echo "grown_defects_count_raw_value{${labels},smart_id=\"12\"} ${grown_defects}"
}

parse_smartctl_nvme_attributes() {
  local disk="$1"
  local disk_type="$2"
  local labels="disk=\"${disk}\",type=\"${disk_type}\""
  local attr_type attr_value
  while read -r line; do
    attr_type="$(echo "${line}" | cut -f1 -d: | tr -s ' ' '_')"
    # The number before any unit or [...]: "12,345 [6.32 TB]" -> 12345, "3%" -> 3
    attr_value="$(echo "${line}" | cut -f2- -d: | sed 's/^ \+//g' | cut -f1 -d' ' | tr -d ',%')"
    case "${attr_type}" in
    Critical_Warning) echo "nvme_critical_warning{${labels}} $((attr_value))" ;;
    Temperature) echo "temperature_celsius_raw_value{${labels},smart_id=\"194\"} ${attr_value}" ;;
    Available_Spare) echo "nvme_available_spare{${labels}} ${attr_value}" ;;
    Available_Spare_Threshold) echo "nvme_available_spare_threshold{${labels}} ${attr_value}" ;;
    Percentage_Used) echo "nvme_percentage_used{${labels}} ${attr_value}" ;;
    Data_Units_Read) echo "nvme_data_units_read{${labels}} ${attr_value}" ;;
    Data_Units_Written) echo "nvme_data_units_written{${labels}} ${attr_value}" ;;
    Host_Read_Commands) echo "nvme_host_read_commands{${labels}} ${attr_value}" ;;
    Host_Write_Commands) echo "nvme_host_write_commands{${labels}} ${attr_value}" ;;
    Controller_Busy_Time) echo "nvme_controller_busy_time{${labels}} ${attr_value}" ;;
    Power_Cycles) echo "power_cycle_count_raw_value{${labels},smart_id=\"12\"} ${attr_value}" ;;
    Power_On_Hours) echo "power_on_hours_raw_value{${labels},smart_id=\"9\"} ${attr_value}" ;;
    Unsafe_Shutdowns) echo "nvme_unsafe_shutdowns{${labels}} ${attr_value}" ;;
    Media_and_Data_Integrity_Errors) echo "nvme_media_errors{${labels}} ${attr_value}" ;;
    Error_Information_Log_Entries) echo "nvme_error_log_entries{${labels}} ${attr_value}" ;;
    Warning_Comp._Temperature_Time) echo "nvme_warning_temp_time{${labels}} ${attr_value}" ;;
    Critical_Comp._Temperature_Time) echo "nvme_critical_temp_time{${labels}} ${attr_value}" ;;
    esac
  done
}

parse_smartctl_info() {
  local -i smart_available=0 smart_enabled=0 smart_healthy=
  local disk="$1" disk_type="$2"
  local model_family='' device_model='' serial_number='' fw_version='' vendor='' product='' revision='' lun_id=''
  while read -r line; do
    info_type="$(echo "${line}" | cut -f1 -d: | tr ' ' '_')"
    info_value="$(echo "${line}" | cut -f2- -d: | sed 's/^ \+//g' | sed 's/"/\\"/')"
    case "${info_type}" in
    Model_Family) model_family="${info_value}" ;;
    Device_Model | Model_Number) device_model="${info_value}" ;;
    Serial_Number) serial_number="${info_value}" ;;
    Firmware_Version) fw_version="${info_value}" ;;
    Vendor) vendor="${info_value}" ;;
    Product) product="${info_value}" ;;
    Revision) revision="${info_value}" ;;
    Logical_Unit_id) lun_id="${info_value}" ;;
    esac
    if [[ "${info_type}" == 'SMART_support_is' ]]; then
      case "${info_value:0:7}" in
      Enabled) smart_available=1; smart_enabled=1 ;;
      Availab) smart_available=1; smart_enabled=0 ;;
      Unavail) smart_available=0; smart_enabled=0 ;;
      esac
    fi
    if [[ "${info_type}" == 'SMART_overall-health_self-assessment_test_result' ]]; then
      case "${info_value:0:6}" in
      PASSED) smart_healthy=1 ;;
      *) smart_healthy=0 ;;
      esac
    elif [[ "${info_type}" == 'SMART_Health_Status' ]]; then
      case "${info_value:0:2}" in
      OK) smart_healthy=1 ;;
      *) smart_healthy=0 ;;
      esac
    fi
  done
  echo "device_info{disk=\"${disk}\",type=\"${disk_type}\",vendor=\"${vendor}\",product=\"${product}\",revision=\"${revision}\",lun_id=\"${lun_id}\",model_family=\"${model_family}\",device_model=\"${device_model}\",serial_number=\"${serial_number}\",firmware_version=\"${fw_version}\"} 1"
  echo "device_smart_available{disk=\"${disk}\",type=\"${disk_type}\"} ${smart_available}"
  echo "device_smart_enabled{disk=\"${disk}\",type=\"${disk_type}\"} ${smart_enabled}"
  [[ "${smart_healthy}" != "" ]] && echo "device_smart_healthy{disk=\"${disk}\",type=\"${disk_type}\"} ${smart_healthy}"
}

output_format_awk="$(
  cat <<'OUTPUTAWK'
BEGIN { v = "" }
v != $1 {
  print "# HELP smartmon_" $1 " SMART metric " $1;
  print "# TYPE smartmon_" $1 " gauge";
  v = $1
}
{print "smartmon_" $0}
OUTPUTAWK
)"

format_output() {
  sort |
    awk -F'{' "${output_format_awk}"
}

# Prints "<device>|<type>" for each disk on USB that --scan-open left out
# (smartctl does not know every USB bridge) and that answers to one of
# the types in SMARTMON_USB_TYPES, tried in order.
list_usb_devices() {
  local scanned="$1" link name type out
  for link in "${SMARTMON_SYSFS}"/block/sd*; do
    [[ -L "${link}" ]] || continue
    [[ "$(readlink "${link}")" == */usb* ]] || continue
    name="$(basename "${link}")"
    # An empty bay of the enclosure has no medium
    [[ "$(cat "${link}/size" 2>/dev/null)" -gt 0 ]] || continue
    grep -qx "/dev/${name}|.*" <<<"${scanned}" && continue
    for type in ${SMARTMON_USB_TYPES}; do
      # -n standby: a spun down disk is not woken up, and its type still
      # counts as found when it answers to the power mode check
      if out="$("${SMARTCTL}" -n standby -i -d "${type}" "/dev/${name}")" ||
        grep -qE '^Device is in (STANDBY|SLEEP)' <<<"${out}"; then
        echo "/dev/${name}|${type}"
        break
      fi
    done
  done
}

SMARTCTL="${SMARTCTL:-/usr/sbin/smartctl}"
SMARTMON_SYSFS="${SMARTMON_SYSFS:-/sys}"
# Set it empty to read no disk --scan-open does not list
SMARTMON_USB_TYPES="${SMARTMON_USB_TYPES-sat}"

smartctl_version="$("${SMARTCTL}" -V | head -n1 | awk '$1 == "smartctl" {print $2}')"

echo "smartctl_version{version=\"${smartctl_version}\"} 1" | format_output

if [[ "$(expr "${smartctl_version}" : '\([0-9]*\)\..*')" -lt 6 ]]; then
  exit
fi

device_list="$("${SMARTCTL}" --scan-open | awk '/^\/dev/{print $1 "|" $3}')"
device_list="${device_list}
$(list_usb_devices "${device_list}")"

for device in ${device_list}; do
  disk="$(echo "${device}" | cut -f1 -d'|')"
  type="$(echo "${device}" | cut -f2 -d'|')"
  active=1
  echo "smartctl_run{disk=\"${disk}\",type=\"${type}\"}" "$(TZ=UTC date '+%s')"
  # Check if the device is in a low-power mode
  "${SMARTCTL}" -n standby -d "${type}" "${disk}" > /dev/null || active=0
  echo "device_active{disk=\"${disk}\",type=\"${type}\"}" "${active}"
  # Skip further metrics to prevent the disk from spinning up
  test ${active} -eq 0 && continue
  # Get the SMART information and health
  "${SMARTCTL}" -i -H -d "${type}" "${disk}" | parse_smartctl_info "${disk}" "${type}"
  # Get the SMART attributes
  case ${type} in
  sat | sat,* | usb*) "${SMARTCTL}" -A -d "${type}" "${disk}" | parse_smartctl_attributes "${disk}" "${type}" ;;
  sat+megaraid*) "${SMARTCTL}" -A -d "${type}" "${disk}" | parse_smartctl_attributes "${disk}" "${type}" ;;
  scsi) "${SMARTCTL}" -A -d "${type}" "${disk}" | parse_smartctl_scsi_attributes "${disk}" "${type}" ;;
  megaraid*) "${SMARTCTL}" -A -d "${type}" "${disk}" | parse_smartctl_scsi_attributes "${disk}" "${type}" ;;
  nvme*) "${SMARTCTL}" -A -d "${type}" "${disk}" | parse_smartctl_nvme_attributes "${disk}" "${type}" ;;
  *)
      (>&2 echo "disk type is not sat, scsi, nvme or megaraid but ${type}")
    exit
    ;;
  esac
done | format_output
