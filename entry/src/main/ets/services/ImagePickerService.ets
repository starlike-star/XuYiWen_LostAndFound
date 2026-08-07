import { photoAccessHelper } from '@kit.MediaLibraryKit';

export class ImagePickerService {
  async pickImages(maximum: number = 6): Promise<string[]> {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maximum;
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
    return result.photoUris;
  }
}
