#! /bin/bash
# ML model installer, ripped out of zmeventnotification/install.sh

TARGET_DATA='/var/lib/zmeventnotification'
WGET=${WGET:-$(which wget)}

# First YOLOV3
echo 'Checking for YoloV3 data files....'
targets=('yolov3.cfg' 'coco.names' 'yolov3.weights')
sources=('https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3.cfg'
        'https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names'
        'https://pjreddie.com/media/files/yolov3.weights')

[ -f "${TARGET_DATA}/models/yolov3/yolov3_classes.txt" ] && rm "${TARGET_DATA}/models/yolov3/yolov3_classes.txt"

for ((i=0;i<${#targets[@]};++i))
do
    if [ ! -f "${TARGET_DATA}/models/yolov3/${targets[i]}" ]
    then
        ${WGET} "${sources[i]}"  -O"${TARGET_DATA}/models/yolov3/${targets[i]}"
    else
        echo "${targets[i]} exists, no need to download"

    fi
done

# Next up, TinyYOLOV3

[ -d "${TARGET_DATA}/models/tinyyolo" ] && mv "${TARGET_DATA}/models/tinyyolo" "${TARGET_DATA}/models/tinyyolov3"
echo
echo 'Checking for TinyYOLOV3 data files...'
targets=('yolov3-tiny.cfg' 'coco.names' 'yolov3-tiny.weights')
sources=('https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3-tiny.cfg'
        'https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names'
        'https://pjreddie.com/media/files/yolov3-tiny.weights')

[ -f "${TARGET_DATA}/models/tinyyolov3/yolov3-tiny.txt" ] && rm "${TARGET_DATA}/models/yolov3/yolov3-tiny.txt"

for ((i=0;i<${#targets[@]};++i))
do
    if [ ! -f "${TARGET_DATA}/models/tinyyolov3/${targets[i]}" ]
    then
        ${WGET} "${sources[i]}"  -O"${TARGET_DATA}/models/tinyyolov3/${targets[i]}"
    else
        echo "${targets[i]} exists, no need to download"

    fi
done

# Next up, TinyYOLOV4
echo 'Checking for TinyYOLOV4 data files...'
targets=('yolov4-tiny.cfg' 'coco.names' 'yolov4-tiny.weights')
sources=('https://raw.githubusercontent.com/AlexeyAB/darknet/master/cfg/yolov4-tiny.cfg'
        'https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names'
        'https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights')

for ((i=0;i<${#targets[@]};++i))
do
    if [ ! -f "${TARGET_DATA}/models/tinyyolov4/${targets[i]}" ]
    then
        ${WGET} "${sources[i]}"  -O"${TARGET_DATA}/models/tinyyolov4/${targets[i]}"
    else
        echo "${targets[i]} exists, no need to download"

    fi
done

# Next up, YoloV4
if [ -d "${TARGET_DATA}/models/cspn" ]
then 
    echo "Removing old CSPN files, it is YoloV4 now"
    rm -rf "${TARGET_DATA}/models/cspn" 2>/dev/null
fi


echo
echo 'Checking for YOLOV4 data files...'
print_warning 'Note, you need OpenCV 4.4+ for Yolov4 to work'
targets=('yolov4.cfg' 'coco.names' 'yolov4.weights')
sources=('https://raw.githubusercontent.com/AlexeyAB/darknet/master/cfg/yolov4.cfg'
        'https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names'
        'https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v3_optimal/yolov4.weights'
        )

for ((i=0;i<${#targets[@]};++i))
do
    if [ ! -f "${TARGET_DATA}/models/yolov4/${targets[i]}" ]
    then
        ${WGET} "${sources[i]}"  -O"${TARGET_DATA}/models/yolov4/${targets[i]}"
    else
        echo "${targets[i]} exists, no need to download"

    fi
done
