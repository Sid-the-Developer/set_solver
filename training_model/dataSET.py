import os
import torch

from torchvision.io import read_image
from torchvision import tv_tensors
import xml.etree.ElementTree as ET
from torchvision.transforms.v2 import functional as F

class DataSET(torch.utils.data.Dataset):
    def __init__(self, root, transforms, device):
        self.root = root
        self.transforms = transforms
        self.device = device

        files = []
        for root, dirs, files in os.walk(os.path.join(root, 'boxes')):
            files += files

        self.boxes = sorted(files)
        self.images = [f'{os.path.splitext(file)[0]}.jpg' for file in files]

        colors = 'red','green','purple'
        nums = 'one','two','three'
        shades = 'empty','partial','full'
        shapes = 'diamond','oval','squiggle'
        self.label_names = [f'{num} {color} {shape} {shade}' for num in nums for color in colors for shape in shapes for shade in shades]

    def __getitem__(self, idx):
        img_path = os.path.join(self.root, 'dataSET.jpg', self.images[idx])
        box_path = os.path.join(self.root, 'boxes', self.boxes[idx])

        labels = []
        boxes = []
        xml = ET.parse(box_path).getroot()
        objects = xml.findall('object')
        for tag in objects:
            labels.append(self.label_names.index(tag.find('name').text) + 1)
            box = tag.find('bndbox')

            xmin = int(box.find('xmin').text)
            xmax = int(box.find('xmax').text)
            ymin = int(box.find('ymin').text)
            ymax = int(box.find('ymax').text)
            boxes.append([xmin, ymin, xmax, ymax])

        img = tv_tensors.Image(read_image(img_path)) / 255
        image_id = idx
        labels = torch.tensor(labels)
        boxes = tv_tensors.BoundingBoxes(boxes, format=tv_tensors.BoundingBoxFormat.XYXY, canvas_size=F.get_size(img))

        area = (boxes[:, 3] - boxes[:, 1]) * (boxes[:, 2] - boxes[:, 0])

        target = {
            'boxes': boxes,
            'labels': labels,
            'image_id': image_id,
            'area': area,
        }

        if self.transforms is not None:
            img, target = self.transforms(img, target)

        return img, target

    def __len__(self):
        return len(self.images)