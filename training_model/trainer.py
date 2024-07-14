import json
import tensorflow as tf

from mediapipe_model_maker import object_detector
import shutil

import os
from os import path
from os.path import join, relpath
import random

import xml.etree.ElementTree as ET

import tensorflow as tf

tf.get_logger().setLevel('ERROR')
from absl import logging

logging.set_verbosity(logging.ERROR)

import numpy as np
import faulthandler
faulthandler.enable()

for dirpath, dirname, filenames in os.walk('boxes'):
    for file in filenames:
        tree = ET.parse(join(dirpath, file))
        filename = f'{"_".join(dirpath.split(os.sep)[1:])}_{path.splitext(file)[0]}.xml'
        tree.write(join('pascal_voc_data/boxes', filename))


def split(train_dir, validation_dir):
    files = os.listdir('pascal_voc_data/boxes')
    indices = np.random.choice(np.arange(len(files)), size=int(.2 * len(files)), replace=False)

    # clean previous data directories
    for dir in [train_dir, validation_dir]:
        shutil.rmtree(dir)
        os.makedirs(join(dir, 'images'))
        os.makedirs(join(dir, 'Annotations'))

    print('copying files', len(files))
    for i, file in enumerate(files):
        filename = path.splitext(file)[0]

        if i in indices:
            dir = validation_dir
        else:
            dir = train_dir

        print(i, dir, filename)
        shutil.copy2(join('pascal_voc_data/dataSET.jpg', f'{filename}.jpg'), join(dir, 'images'))
        shutil.copy2(join('pascal_voc_data/boxes', f'{filename}.xml'), join(dir, 'Annotations'))


def train(train_dir, validation_dir):
    print('training')
    train_data = object_detector.Dataset.from_pascal_voc_folder(data_dir=train_dir, max_num_images=1)
    print('done', train_data)
    validation_data = object_detector.Dataset.from_pascal_voc_folder(data_dir=validation_dir, max_num_images=1)
    # print('validation done', validation_data)
    # # test_data = object_detector.DataLoader.from_pascal_voc(images_dir='dataSET.jpg', annotations_dir='boxes', annotation_filenames=test_annotations, label_map=label_names)

    return train_data, validation_data


train_dir = 'pascal_voc_data/train'
validation_dir = 'pascal_voc_data/validation'

# train, validation = train(train_dir, validation_dir)
# print(train, validation)
train_data = object_detector.Dataset.from_pascal_voc_folder(data_dir=train_dir)
validation_data = object_detector.Dataset.from_pascal_voc_folder(data_dir=validation_dir)
# print('validation done', validation_data)
# # test_data = object_detector.DataLoader.from_pascal_voc(images_dir='dataSET.jpg', annotations_dir='boxes', annotation_filenames=test_annotations, label_map=label_names)

print(train_data.size, validation_data.size)

spec = object_detector.SupportedModels.MOBILENET_MULTI_AVG
hparams = object_detector.HParams(export_dir='exported_model')
options = object_detector.ObjectDetectorOptions(
    supported_model=spec,
    hparams=hparams
)

model = object_detector.ObjectDetector.create(
    train_data=train_data,
    validation_data=validation_data,
    options=options)

loss, coco_metrics = model.evaluate(validation_data, batch_size=4)
print(f"Validation loss: {loss}")
print(f"Validation coco metrics: {coco_metrics}")

model.export_model(f'{spec}-model.tflite')
