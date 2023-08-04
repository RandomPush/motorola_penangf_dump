#!/system/bin/sh
#!/bin/bash


######################MODIFY ME##############################
FT_EXEC=/vendor/bin/ft_autotest
######################MODIFY ME##############################

############# Common Function ###############################
## SERVICE ID AND COMMAND ID OF UTAG
CMD_UTAG_RD="2501"
CMD_UTAG_WR="2502"
TEST_RESULT_NODE="test.result"

# asciid to hex string, maybe buggy.
# xxd change to newline every 16-bytes so we use echo -n to replace \n and tr -d ' ' to replace spaces.
# change to use printf instead of xxd?
function ascii_to_hex
{
    hex_val=$(echo -n $1 | xxd -p)
    echo -n $hex_val|tr -d ' '
}

function hex_to_ascii
{
    ascii_val=$(echo -n $1 | xxd -r -p)
    echo $ascii_val
}

function str_len
{
    local len=${#1}
    echo `expr $len / 2`
}

function pack_cmd
{
    len=$(printf '%04x' `expr $1 + 2`)
    local id=$2
    local payload=$3
    #pad head and crc
    local cmd="7e"$len$id$payload"0000"
    echo $cmd
}

function read_utag_config
{
    local fixed="config:"
    local tag=$fixed$1

    tag_hex=$(ascii_to_hex $tag)
    tag_size=$(str_len $tag_hex)
    cmd=$(pack_cmd $tag_size $CMD_UTAG_RD $tag_hex)
    sh -c "$FT_EXEC -c $cmd"
}

function write_utag_config
{
    local fixed="config:"
    local tag=$fixed$1":"$2

    tag_hex=$(ascii_to_hex $tag)
    tag_size=$(str_len $tag_hex)
    cmd=$(pack_cmd $tag_size $CMD_UTAG_WR $tag_hex)
    sh -c "$FT_EXEC -c $cmd"
}

function read_utag_hw
{
    local fixed="hw:"
    local tag=$fixed$1

    tag_hex=$(ascii_to_hex $tag)
    tag_size=$(str_len $tag_hex)
    cmd=$(pack_cmd $tag_size $CMD_UTAG_RD $tag_hex)
    sh -c "$FT_EXEC -c $cmd"
}

function write_utag_hw
{
    local fixed="hw:"
    local tag=$fixed$1":"$2

    tag_hex=$(ascii_to_hex $tag)
    tag_size=$(str_len $tag_hex)
    cmd=$(pack_cmd $tag_size $CMD_UTAG_WR $tag_hex)
    sh -c "$FT_EXEC -c $cmd"
}
############# Common Function ###############################

#################Group:UTAG start############################
function UTAG_BATTERY_ID
{
    read_utag_hw "battid"
}

function UTAG_SET_BATTERY_ID
{
    write_utag_hw "battid" $1
}

function check_test_flag
{
    local reloadFile="/proc/hw/reload"
    local test_result_file=$1
    local test_result_empty="00000000000000000000000000000000"
    local loaded=998
    local retry=0

    while(( $retry < 10 )); do
        let loaded=$(cat $reloadFile)
        if [ $loaded = 0 ]; then
            if [ ! -d /proc/hw/$test_result_file ]; then
                echo $test_result_file > /proc/hw/all/new
                sleep 2
                echo $test_result_empty > /proc/hw/$test_result_file/ascii
            fi
            break
        fi
        sleep 0.5
        let "retry++"
    done

    echo $loaded
}

function is_test_flag_legal
{
    local strIndex=$(expr ${#1} - 1)
    for i in `seq 0 $strIndex`; do
        if [ ${1:$i:1} != "0" ] && [ ${1:$i:1} != "1" ]; then
            echo 1
            return
        fi
    done
    echo 0
}

function UTAG_TESTRESULT
{
    local retVal=$(check_test_flag $TEST_RESULT_NODE)
    if [ $retVal = 0 ]; then
        read_utag_hw $TEST_RESULT_NODE
    else
        # shell error send UTAG_WRITE_ERROR to PC
        echo "7E00062501000025031528"
    fi
}

function UTAG_SET_TESTRESULT
{
    local retVal=$(check_test_flag $TEST_RESULT_NODE)
    local strLegal=$(is_test_flag_legal $1)

    if [ ${#1} -ne 32 ] || [ $strLegal -ne 0 ]; then
        # accept 32-bytes-long string only contains '0' or '1'
        echo "7E000625020000000302E9"
        exit
    fi
    if [ $retVal = 0 ]; then
        write_utag_hw $TEST_RESULT_NODE $1
    else
        # shell error send UTAG_WRITE_ERROR to PC
        echo "7E00062502000025048B1D"
    fi
}

function TESTRESULT_SYNC_TO_PROINFO
{
    local cmd="7E00021401DF96"
    sh -c "$FT_EXEC -c $cmd"
}

#################Group:UTAG end##############################

#################Group:Turn On & off Start###################
# TODO
function CHECK_POWER_UP
{
    local cmd="7E00021806EA1C"
    sh -c "$FT_EXEC -c $cmd"
}

# power off
# TODO
function POWER_OFF
{
    sh -c "$FT_EXEC -c $cmd"
}

# read trackid.
# On success: return trackid(64-bytes hex string with null terminator)
function READ_TRACK_ID
{
    local cmd="7E00021804CA5E"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:Turn On & off End#####################
#################Group:PHONE_INFO start######################
# TODO
function READ_HW_VERSION
{
    sh -c "$FT_EXEC -c $cmd"
}

# TODO
function READ_HW_ID
{
    local cmd="7E000218050000"
    sh -c "$FT_EXEC -c $cmd"
}

# TODO
function READ_SW_VERSION
{
    local cmd="7E000218070000"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:PHONE_INFO End########################
#################Group:NVM_INFO start########################
# get ufs/emmc model.
# On Success: return model in hex string.
function READ_NVM_VENDOR_MODEL
{
    local cmd="7E00020A01FFEA"
    sh -c "$FT_EXEC -c $cmd"
}

## get ufs/emmc size.
# On Success: return nvm size(big-edian).
function READ_NVM_SIZE
{
    local cmd="7E00020A02CF89"
    sh -c "$FT_EXEC -c $cmd"
}

## get size of LPDDR.
# On Success: return lpddr size(big-edian).
function GET_RAM_LPDDR_SIZE
{
    local cmd="7E0002220170A5"
    sh -c "$FT_EXEC -c $cmd"
}

## get mmc absent status
# On Success: return status(0 for absent, 1 for not absent)
function GET_MMC_ABSENT_STATUS
{
    local cmd="7E0002210125F6"
    sh -c "$FT_EXEC -c $cmd"
}

## get sdcard card size
# On Success: return status(0 for absent, 1 for not absent)
function READ_SDCARD_SIZE
{
    local cmd="7E000221021595"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:NVM_INFO End##########################
#################Group:THERMISTOR_INFO start#################
# Read the Battery Thermistor value.
# On Success: return thermistor value.
function READ_BATTERY_THERMISTOR_VALUE
{
    local cmd="7E000213050685"
    sh -c "$FT_EXEC -c $cmd"
}

# Read AP's thermistor value.
# On Success: return thermistor value.
function READ_AP_THERMISTOR_VALUE
{
    local cmd="7E000213014601"
    sh -c "$FT_EXEC -c $cmd"
}

# Read PCB's Thermistor value.
# On Success: return thermistor value.
function READ_PCB_THERMISTOR_VALUE
{
    local cmd="7E000213027662"
    sh -c "$FT_EXEC -c $cmd"
}

# Read Charger's Thermistor value.
# On Success: return thermistor value.
function READ_CHARGE_THERMISTOR_VALUE
{
    local cmd="7E000213036643"
    sh -c "$FT_EXEC -c $cmd"
}

# Read PA's Thermistor value.
# On Success: return thermistor value.
function READ_PA_THERMISTOR_VALUE
{
    local cmd="7E0002130416A4"
    sh -c "$FT_EXEC -c $cmd"
}

# Read CPU's Thermistor value.
# On Success: return thermistor value.
function READ_CPU_THERMISTOR_VALUE
{
    local cmd="7E0002130636E6"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:THERMISTOR_INFO End###################
#################Group:SENSOR Test Start#####################
# Selftest of accel.
# On Success: return 0.
function ACCELEROMETER_SELF_TEST
{
    local cmd="7E000201012310"
    sh -c "$FT_EXEC -c $cmd"
}

# Selftest of gyro.
# On Success: return 0.
function GYROSCOPE_SELF_TEST
{
    local cmd="7E0002010473B5"
    sh -c "$FT_EXEC -c $cmd"
}

# Read rawdata for magnet.
# On Success: return rawdata of xyz axes.
function MAGNETOMETER_TEST_MAG_SENSE_READINGS_ONLY_READ
{
    local cmd="7E00020E01332E"
    sh -c "$FT_EXEC -c $cmd"
}

# enable proximity sensor.
# On Success: return 0.
function ENABLE_PROXIMITY_SENSOR
{
    local cmd="7E00022601BC61"
    sh -c "$FT_EXEC -c $cmd"
}

# enable proximity sensor.
# On Success: return 0.
function DISABLE_PROXIMITY_SENSOR
{
    local cmd="7E000226028C02"
    sh -c "$FT_EXEC -c $cmd"
}

# enable proximity sensor.
# On Success: return 0.
function ENABLE_ALS_SENSOR
{
    local cmd="7E0002020536C7"
    sh -c "$FT_EXEC -c $cmd"
}

# enable proximity sensor.
# On Success: return 0.
function DISABLE_ALS_SENSOR
{
    local cmd="7E0002020606A4"
    sh -c "$FT_EXEC -c $cmd"
}

# proximity crosstalk calibration.
# On Success: return 0.
function PROX_CROSSTALK_CALIBRATION
{
    local cmd="7E000226039C23"
    sh -c "$FT_EXEC -c $cmd"
}

# read rawdata(cover) of proximity sensor.
# On Success: return rawdata value(big-edian).
function PROX_READ_COVER_RAWDATA
{
    local cmd="7E00022604ECC4"
    sh -c "$FT_EXEC -c $cmd"
}

# write rawdata of proximity sensor.
# On Success: return 0.
function PROX_WRITE_COVER_RAWDATA
{
    local fixed="7E00062605"
    local payload=$1
    local crc="0000"
    local cmd=$fixed$payload$crc
    sh -c "$FT_EXEC -c $cmd"
}

# proximity sensor threshold calibration.
# On Success: return 0.
function PROX_EXECUTE_THRESHOLD_CALIBRATION
{
    local cmd="7E00022606CC86"
    sh -c "$FT_EXEC -c $cmd"
}

# read proximity sensor threshold.
# On Success: return 0.
function PROX_READ_THRESHOLD
{
    local cmd="7E00022607DCA7"
    sh -c "$FT_EXEC -c $cmd"
}

# read light sensor's data(lux,ch0, ch1).
# On Success: return (lux,ch0, ch1)'s value(big-edian).
function LIGHT_SENSOR_READ_FROM_PHONE_3CH
{
    local cmd="7E000202017643"
    sh -c "$FT_EXEC -c $cmd"
}

# Obtain the ALS calibration coefficient after a delay of 2s.
# On Success: return the ALS calibration coefficient.
function LIGHT_SENSOR_CALIBRATION_VERIFY_COEFFICIENTS
{
    local cmd="7E0002020426E6"
    sh -c "$FT_EXEC -c $cmd"
}

# Light sensor calibration.
# On Success: return 0.
function LIGHT_SENSOR_CALIBRATION_EXCUTE_CALI
{
    local cmd="7E000202035601"
    sh -c "$FT_EXEC -c $cmd"
}

# send light sensor target lux.
# On Success: return 0.
function LIGHT_SENSOR_CALIBRATION_WRITE_TARGET
{
    local fixed="7E00060202"
    local payload=$1
    local crc="0000"
    local cmd=$fixed$payload$crc
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:SENSOR Test End#####################
#################Group:Audio Start#########################
# Selftest of MIC.
# On Success: return 0.
function MIC_ENABLE
{
    local cmd="7E000203014572"
    sh -c "$FT_EXEC -c $cmd"
}

function MIC_SELF_TEST
{
    local cmd="7E000203027511"
    sh -c "$FT_EXEC -c $cmd"
}

#################Group:Audio End###########################
#################Group:CAP SENSOR BOARD TEST Start#########
# Selftest of CAP sensor.
# On Success: return 0.
function CAP_SENSOR_DETECT
{
    local cmd="7E000208019988"
    sh -c "$FT_EXEC -c $cmd"
}

# Enable CAP sensor.
# On Success: return 0.
function CAP_SENSOR_ENABLE
{
    local cmd="7E00020802A9EB"
    sh -c "$FT_EXEC -c $cmd"
}

# Calibrate RF sensor.
# On Success: return 0.
function CAP_SENSOR_EXECUTE_SELF_CALIBRATION
{
    local cmd="7E00020804C92D"
    sh -c "$FT_EXEC -c $cmd"
}

#read Board level Capacitor Compensation Value
# On Success: return values of channel CS0~CS5.
function CAP_SENSOR_READ_BOARD_LEVEL_CAP_VALUE
{
    local cmd="7E00020805D90C"
    sh -c "$FT_EXEC -c $cmd"
}

## Store Board level Capacitor Compensation Value
## parameters repesents CS0 ~ CS5, decimal.
#function CAP_SENSOR_STORE_BOARD_LEVEL_CAP_VALUE
#{
#    local fixed="7E000E0806"
#    local payload=$(printf '%04x%04x%04x%04x%04x%04x' $1 $2 $3 $4 $5 $6)
#    local crc="0000"
#    local cmd=$fixed$payload$crc
#    sh -c "$FT_EXEC -c $cmd"
#}

function CAP_SENSOR_STORE_BOARD_LEVEL_CAP_VALUE
{
    local fixed="7E000E0806"
    local payload=$1 $2 $3 $4 $5 $6
    local crc="0000"
    local cmd=$fixed$payload$crc
    sh -c "$FT_EXEC -c $cmd"
}

## Test Interrupts status.
## On Success: return 0.
function CAP_SENSOR_READ_INTERRUPTS_STATUS
{
    local cmd="7E0002080808A1"
    sh -c "$FT_EXEC -c $cmd"
}

## Read diff value of RF sensor.
## On Success: return values of channel CS0~CS5.
function CAP_SENSOR_READ_DIFF_VALUE
{
    local cmd="7E00020807F94E"
    sh -c "$FT_EXEC -c $cmd"
}

## Disable CAP sensor.
## On Success: return 0.
function CAP_SENSOR_DISABLE
{
    local cmd="7E00020803B9CA"
    sh -c "$FT_EXEC -c $cmd"
}

## accel calibration
## On Success: return 0.
function ACCLEROMETER_EXECUTE_OFFSET_CALIBRATION
{
    local cmd="7E000201021373"
    sh -c "$FT_EXEC -c $cmd"
}

## read accel offset
## On Success: return 0.
function ACCLEROMETER_READ_OFFSET
{
    local cmd="7E000201030352"
    sh -c "$FT_EXEC -c $cmd"
}

## gyro calibration
## On Success: return 0.
function GYROSCOPE_EXECUTE_OFFSET_CALIBRATION
{
    local cmd="7E000201056394"
    sh -c "$FT_EXEC -c $cmd"
}

## read gyro offset
## On Success: return 0.
function GYROSCOPE_READ_OFFSET
{
    local cmd="7E0002010653f7"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:SENSOR Test End#######################
#################Group:CURRENT TEST Start####################
## switch power source to battery.
## On Success: return 0.
function SWITCH_POWER_SOURCE_TO_BATTERY
{
    local cmd="7E00020901AAB9"
    sh -c "$FT_EXEC -c $cmd"
}

## Turn off LCD display.
## On Success: return 0.
#function QUICK_STANDBY
#{
#    local cmd="7E0003180300BF91"
#    sh -c "$FT_EXEC -c $cmd"
#}

## Enable battery limit(65%).
## On Success: return 0.
function BATT_LIMIT_ON
{
    local cmd="7E000209038AFB"
    sh -c "$FT_EXEC -c $cmd"
}

## Disable battery limit(65%).
## On Success: return 0.
function BATT_LIMIT_OFF
{
    local cmd="7E00020904FA1C"
    sh -c "$FT_EXEC -c $cmd"
}

## Check battery level 50%.
## On Success: return 0.
function READ_BATTERY_LEVEL_VALUE
{
    local cmd="7E00020905EA3D"
    sh -c "$FT_EXEC -c $cmd"
}

## switch power source to charger.
## On Success: return 0.
function SWITCH_POWER_SOURCE_TO_CHARGE
{
    local cmd="7E000209029ADA"
    sh -c "$FT_EXEC -c $cmd"
}

## VBUS_VOLTAGE Reading 10: 5731.
## On Success: return 0.
function READ_VBUS_VOLTAGE
{
    local cmd=" 7E00020906DA5E"
    sh -c "$FT_EXEC -c $cmd"
}

## disable battery fet.
## On Success: return 0.
function DISABLE_BATTERY_FET
{
    local cmd="7E000209092BB1"
    sh -c "$FT_EXEC -c $cmd"
}

## VBAT_VOLTAGE Reading 3: 3399.
## On Success: return 0.
function READ_VBAT_VOLTAGE
{
    local cmd="7E00020907CA7F"
    sh -c "$FT_EXEC -c $cmd"
}

## SET_INPUT_PATH_TO_3_AMPS Reading 3: 3399.
## On Success: return 0.
function SET_INPUT_PATH_TO_3_AMPS
{
    local cmd="7E0002090A1BD2"
    sh -c "$FT_EXEC -c $cmd"
}

## SET_INPUT_PATH_TO_3_AMPS Reading 3: 3399.
## On Success: return 0.
function SET_OUTPUT_PATH_TO_1_AMPS
{
    local cmd="7E0002090B0BF3"
    sh -c "$FT_EXEC -c $cmd"
}

## Set the charging current to 1A.
## On Success: return 0.
function ENABLE_PATH_FET_TO_BATTERY
{
    local cmd="7E000209083B90"
    sh -c "$FT_EXEC -c $cmd"
}

#
# Enable Cap SWITCH.
## On Success: return 0.
function ENABLE_CAP_SWITCH
{
    local cmd="7E0002090C7B14"
    sh -c "$FT_EXEC -c $cmd"
}

## Disable Cap SWITCH.
## On Success: return 0.
function DISABLE_CAP_SWITCH
{
    local cmd="7E0002090D6B35"
    sh -c "$FT_EXEC -c $cmd"
}

## Detect charger type plugged in
## On Success: return 0.
function READ_DCP_STATUS
{
    local cmd="7E0002090F6B35"
    sh -c "$FT_EXEC -c $cmd"
}

## Detect charger type plugged in
## On Success: return 0.
function GET_TYPE_C_STATE
{
    local cmd="7E0002090E5B56"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:CURRENT TEST End######################
#################Group:NFC TEST Start########################
## enter test mode.
## On Success: return 0.
function ENABLE_NFC_TEST_MODE
{
    local cmd="7E000212035572"
    sh -c "$FT_EXEC -c $cmd"
}

## reset NFC.
## On Success: return 0.
function RESET_NFC
{
    local cmd="7E000212017530"
    sh -c "$FT_EXEC -c $cmd"
}

## disable NFC.
## On Success: return 0.
function DISABLE_NFC
{
    local cmd="7E000212024553"
    sh -c "$FT_EXEC -c $cmd"
}

## antenna self test.
## On Success: return 0.
function NFC_ANTENNA_SELFTEST
{
    local cmd="7E0002120535B4"
    sh -c "$FT_EXEC -c $cmd"
}

## SWP line self test.
## On Success: return 0.
function START_NFC_SWP_SELF_TEST_BOARD
{
    local cmd="7E000212042595"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:NFC TEST End##########################
#################Group:BT & WLAN TEST Start##################
## enable BT.
## On Success: return 0.
function ENABLE_BT
{
    local cmd="7E0002070189B6"
    sh -c "$FT_EXEC -c $cmd"
}

## disable BT.
## On Success: return 0.
function DISABLE_BT
{
    local cmd="7E00020702B9D5"
    sh -c "$FT_EXEC -c $cmd"
}

## enable WLAN.
## On Success: return 0.
function ENABLE_WLAN
{
    local cmd="7E00022401DA03"
    sh -c "$FT_EXEC -c $cmd"
}

## disable WLAN.
## On Success: return 0.
function DISABLE_WLAN
{
    local cmd="7E00022402EA60"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:BT & WLAN TEST End####################
#################Group:Modem TEST Start######################
## Detect SIM1 not inserted status.
## On Success: return 0.
function VERIFY_SIM1_REMOVE_STATUS
{
    local cmd="7E000227018F50"
    sh -c "$FT_EXEC -c $cmd"
}

## Detect SIM2 not inserted status.
## On Success: return 0.
function VERIFY_SIM2_REMOVE_STATUS
{
    local cmd="7E00022702BF33"
    sh -c "$FT_EXEC -c $cmd"
}

## Detect SIM card tray not inserted.
## On Success: return 0.
function GET_SIM_ABSENT_STATUS
{
    local cmd="7E00022703AF12"
    sh -c "$FT_EXEC -c $cmd"
}
#################Group:Modem TEST End########################
#################Group:TP&LCD TEST Start#####################
## TP range test.
## On Success: return 0.
function START_TOUCHSCREEN_TEST
{
    local cmd="7E00021901A9CA"
    sh -c "$FT_EXEC -c $cmd"
}

## get LCD Vendor ID.
## On Success: return 0.
function READ_LCD_VENDOR_INFO
{
    local cmd="7E00020D01667D"
    sh -c "$FT_EXEC -c $cmd"
}

## Fingerprint sensor selftest.
## On Success: return 0.
function FINGERPRINT_SENSOR_SELF_TEST
{
    local cmd="7E000228018F50"
    sh -c "$FT_EXEC -c $cmd"
}

function AUDIO_BYPASS_AGLO
{
    local cmd="7E000203036530"
    sh -c "$FT_EXEC -c $cmd"
}

function AUDIO_ENABLE_ALGO
{
    local cmd="7E0002030415D7"
    sh -c "$FT_EXEC -c $cmd"
}

function BT_ON
{
    svc bluetooth disable
}

function QUICK_STANDBY
{
    result="$(dumpsys deviceidle | grep -c mScreenOn=false)"
    if [ "$result" == 1 ]; then
        echo "7E0006180300000000F914"

    else
        input keyevent 26
        echo "7E0006180300000000F914"
    fi
}

function SCREEN_WAKEUP
{
    result="$(dumpsys deviceidle | grep -c mScreenOn=true)"
    if [ "$result" == 1 ]; then
        echo "7E0006180400000000F914"

    else
        input keyevent 26
        echo "7E0006180400000000F914"
    fi
}

## 4G Camera Cal
## On Success: return 0.
function START_DEPTH_CALIBRATION
{
    local cmd="7E00021C01563F"
    sh -c "$FT_EXEC -c $cmd"
}

## 4G Camera Verify
## On Success: return 0.
function START_DEPTH_VERIFICATION
{
    local cmd="7E00021C02665C"
    sh -c "$FT_EXEC -c $cmd"
}

## 4G+ Camera Cal
## On Success: return 0.
function START_WIDTH_CALIBRATION
{
    local cmd="7E00021C03767D"
    sh -c "$FT_EXEC -c $cmd"
}

## 4G+ Camera Verify
## On Success: return 0.
function START_WIDTH_VERIFICATION
{
    local cmd="7E00021C04069A"
    sh -c "$FT_EXEC -c $cmd"
}

#################Group:TP&LCD TEST End#######################
##### Main #####
eval $@
