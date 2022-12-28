//
//  TaglibWrapper.mm
//
//  Created by Ryan Francesconi on 1/2/19.
//  Copyright © 2019 Ryan Francesconi. All rights reserved.
//

#include <iostream>
#include <iomanip>
#include <stdio.h>
#import <taglib/tag.h>
#import <taglib/fileref.h>
#import <taglib/tstring.h>
#import <taglib/rifffile.h>
#import <taglib/wavfile.h>
#import <taglib/aifffile.h>
#import <taglib/flacfile.h>
#import <taglib/mpegfile.h>
#import <taglib/mp4file.h>
#import <taglib/chapterframe.h>
#import <taglib/tstringlist.h>
#import <taglib/tpropertymap.h>
#import <taglib/textidentificationframe.h>
#import <taglib/tfilestream.h>
#import <taglib/attachedpictureframe.h>
#import "TaglibWrapper.h"

using namespace std;

@implementation TaglibWrapper

const NSString *AP_LENGTH = @"AP_LENGTH";
const NSString *AP_BITRATE = @"AP_BITRATE";
const NSString *AP_SAMPLERATE = @"AP_SAMPLERATE";
const NSString *AP_BITSPERSAMPLE = @"AP_BITSPERSAMPLE";

+ (nullable NSString *)getTitle:(NSString *)path
{
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return nil;
    }
    
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        return nil;
    }
    NSString *value = [NSString stringWithUTF8String:tag->title().toCString()];
    return value;
}

+ (nullable NSString *)getComment:(NSString *)path
{
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        cout << "FileRef is nil for: " << path.UTF8String << endl;
        return nil;
    }
    
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        cout << "Tag is nil" << endl;
        return nil;
    }
    NSString *value = [NSString stringWithUTF8String:tag->comment().toCString()];
    return value;
}

+ (nullable NSMutableDictionary *)getMetadata:(NSString *)path
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return nil;
    }
    
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        return nil;
    }
    //    cout << "-- TAG (basic) --" << endl;
    //    cout << "title   - \"" << tag->title()   << "\"" << endl;
    //    cout << "artist  - \"" << tag->artist()  << "\"" << endl;
    //    cout << "album   - \"" << tag->album()   << "\"" << endl;
    //    cout << "year    - \"" << tag->year()    << "\"" << endl;
    //    cout << "comment - \"" << tag->comment() << "\"" << endl;
    //    cout << "track   - \"" << tag->track()   << "\"" << endl;
    //    cout << "genre   - \"" << tag->genre()   << "\"" << endl;
    
    TagLib::RIFF::WAV::File *waveFile = dynamic_cast<TagLib::RIFF::WAV::File *>(fileRef.file());
    
    NSString *title = [TaglibWrapper stringFromWchar:tag->title().toCWString()];
    
    // if title is blank, check the wave info tag instead
    if (title == nil && waveFile) {
        title = [TaglibWrapper stringFromWchar:waveFile->InfoTag()->title().toCWString()];
    }
    [dictionary setValue:title ? : @"" forKey:@"TITLE"];
    
    NSString *artist = [TaglibWrapper stringFromWchar:tag->artist().toCWString()];
    
    if ((artist == nil || [artist isEqualToString:@""]) && waveFile) {
        artist = [TaglibWrapper stringFromWchar:waveFile->InfoTag()->artist().toCWString()];
    }
    [dictionary setValue:artist ? : @"" forKey:@"ARTIST"];
    
    NSString *album = [TaglibWrapper stringFromWchar:tag->album().toCWString()];
    if ((album == nil || [album isEqualToString:@""]) && waveFile) {
        album = [TaglibWrapper stringFromWchar:waveFile->InfoTag()->album().toCWString()];
    }
    [dictionary setValue:album ? : @"" forKey:@"ALBUM"];
    
    NSString *year = [NSString stringWithFormat:@"%u", tag->year()];
    [dictionary setValue:year forKey:@"YEAR"];
    
    NSString *comment = [TaglibWrapper stringFromWchar:tag->comment().toCWString()];
    if ((comment == nil || [comment isEqualToString:@""]) && waveFile) {
        comment = [TaglibWrapper stringFromWchar:waveFile->InfoTag()->comment().toCWString()];
    }
    [dictionary setValue:comment ? : @"" forKey:@"COMMENT"];
    
    NSString *track = [NSString stringWithFormat:@"%u", tag->track()];
    [dictionary setValue:track ? : @"" forKey:@"TRACK"];
    
    NSString *genre = [TaglibWrapper stringFromWchar:tag->genre().toCWString()];
    if ((genre == nil || [genre isEqualToString:@""]) && waveFile) {
        genre = [TaglibWrapper stringFromWchar:waveFile->InfoTag()->genre().toCWString()];
    }
    [dictionary setValue:genre ? : @"" forKey:@"GENRE"];
    
    TagLib::PropertyMap tags = fileRef.file()->properties();
    
    // scan through the tag properties where all the other id3 tags will be kept
    // add those as additional keys to the dictionary
    //cout << "-- TAG (properties) --" << endl;
    for (TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
        for (TagLib::StringList::ConstIterator j = i->second.begin(); j != i->second.end(); ++j) {
            // cout << i->first << " - " << '"' << *j << '"' << endl;
            
            NSString *key = [TaglibWrapper stringFromWchar:i->first.toCWString()];
            NSString *object = [TaglibWrapper stringFromWchar:j->toCWString()];
            
            if (key != nil && object != nil) {
                [dictionary setValue:object ? : @"" forKey:key];
            }
        }
    }
    return dictionary;
}

+ (bool)setMetadata:(NSString *)path
         dictionary:(NSDictionary *)dictionary
{
    TagLib::FileRef fileRef(path.UTF8String);
    
    if (fileRef.isNull()) {
        cout << "Error: TagLib::FileRef.isNull: Unable to open file:" << path.UTF8String << endl;
        return false;
    }
    
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        cout << "Unable to create tag" << endl;
        return false;
    }
    
    // also duplicate the data into the INFO tag if it's a wave file
    TagLib::RIFF::WAV::File *waveFile = dynamic_cast<TagLib::RIFF::WAV::File *>(fileRef.file());
    
    // these are the non standard tags
    TagLib::PropertyMap tags = fileRef.file()->properties();
    
    for (NSString *key in [dictionary allKeys]) {
        NSString *value = [dictionary objectForKey:key];
        
        if ([key isEqualToString:@"TITLE"]) {
            tag->setTitle(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            // also set InfoTag for wave
            if (waveFile) {
                waveFile->InfoTag()->setTitle(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            }
        } else if ([key isEqualToString:@"ARTIST"]) {
            tag->setArtist(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            if (waveFile) {
                waveFile->InfoTag()->setArtist(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            }
        } else if ([key isEqualToString:@"ALBUM"]) {
            tag->setAlbum(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            if (waveFile) {
                waveFile->InfoTag()->setAlbum(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            }
        } else if ([key isEqualToString:@"YEAR"]) {
            tag->setYear(value.intValue);
            if (waveFile) {
                waveFile->InfoTag()->setYear(value.intValue);
            }
        } else if ([key isEqualToString:@"TRACK"]) {
            tag->setTrack(value.intValue);
            if (waveFile) {
                waveFile->InfoTag()->setTrack(value.intValue);
            }
        } else if ([key isEqualToString:@"COMMENT"]) {
            tag->setComment(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            if (waveFile) {
                waveFile->InfoTag()->setComment(TagLib::String(value.UTF8String, TagLib::String::Type::UTF8));
            }
        }
        
        TagLib::String tagKey = TagLib::String(key.UTF8String, TagLib::String::Type::UTF8);
        TagLib::String tagValue = TagLib::String(value.UTF8String, TagLib::String::Type::UTF8);
        tags.replace(tagKey, TagLib::StringList(tagValue));
    }
    
    tags.removeEmpty();
    fileRef.file()->setProperties(tags);
    bool result = fileRef.save();
    
    return result;
}

void printTags(const TagLib::PropertyMap &tags)
{
    unsigned int longest = 0;
    for (TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
        if (i->first.size() > longest) {
            longest = i->first.size();
        }
    }
    cout << "-- TAG (properties) --" << endl;
    for (TagLib::PropertyMap::ConstIterator i = tags.begin(); i != tags.end(); ++i) {
        for (TagLib::StringList::ConstIterator j = i->second.begin(); j != i->second.end(); ++j) {
            cout << left << std::setw(longest) << i->first << " - " << '"' << *j << '"' << endl;
        }
    }
}

// convenience function to update the comment tag in a file
+ (bool)writeComment:(NSString *)path
             comment:(NSString *)comment
{
    TagLib::FileRef fileRef(path.UTF8String);
    
    if (fileRef.isNull()) {
        cout << "Unable to write comment" << endl;
        return false;
    }
    
    cout << "Updating comment to: " << comment.UTF8String << endl;
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        cout << "Unable to write tag" << endl;
        return false;
    }
    
    tag->setComment(comment.UTF8String);
    bool result = fileRef.save();
    return result;
}

/// markers as chapters in mp3 and mp4 files
+ (NSArray *)getChapters:(NSString *)path
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return nil;
    }
    
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        return nil;
    }
    
    TagLib::MPEG::File *mpegFile = dynamic_cast<TagLib::MPEG::File *>(fileRef.file());
    
    if (!mpegFile) {
        return nil;
    }
    // cout << "Parsing MPEG File" << endl;
    
    TagLib::ID3v2::FrameList chapterList = mpegFile->ID3v2Tag()->frameList("CHAP");
    
    for (TagLib::ID3v2::FrameList::ConstIterator it = chapterList.begin();
         it != chapterList.end();
         ++it) {
        TagLib::ID3v2::ChapterFrame *frame = dynamic_cast<TagLib::ID3v2::ChapterFrame *>(*it);
        if (frame) {
            // cout << "FRAME " << frame->toString() << endl;
            
            if (!frame->embeddedFrameList().isEmpty()) {
                for (TagLib::ID3v2::FrameList::ConstIterator it = frame->embeddedFrameList().begin(); it != frame->embeddedFrameList().end(); ++it) {
                    // the chapter title is a sub frame
                    if ((*it)->frameID() == "TIT2") {
                        // cout << (*it)->frameID() << " = " << (*it)->toString() << endl;
                        NSString *marker = [TaglibWrapper stringFromWchar:(*it)->toString().toCWString()];
                        
                        marker = [marker stringByAppendingString:[NSString stringWithFormat:@"@%d", frame->startTime()] ];
                        [array addObject:marker];
                    }
                }
            }
        }
    }
    
    return array;
}

// only works with mp3 files
+ (bool)setChapters:(NSString *)path
              array:(NSArray *)array
{
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return false;
    }
    
    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        return false;
    }
    TagLib::MPEG::File *mpegFile = dynamic_cast<TagLib::MPEG::File *>(fileRef.file());
    
    if (!mpegFile) {
        cout << "TaglibWrapper.setChapters: Not a MPEG File" << endl;
        return false;
    }
    
    // parse array
    
    // remove CHAPter tags
    mpegFile->ID3v2Tag()->removeFrames("CHAP");
    
    // add new CHAP tags
    TagLib::ID3v2::Header header;
    
    // expecting NAME@TIME right now
    for (NSString *object in array) {
        NSArray *items = [object componentsSeparatedByString:@"@"];
        NSString *name = [items objectAtIndex:0];   //shows Description
        int time = [[items objectAtIndex:1] intValue];
        
        TagLib::ID3v2::ChapterFrame *chapter = new TagLib::ID3v2::ChapterFrame(&header, "CHAP");
        chapter->setStartTime(time);
        chapter->setEndTime(time);
        
        // set the chapter title
        TagLib::ID3v2::TextIdentificationFrame *eF = new TagLib::ID3v2::TextIdentificationFrame("TIT2");
        eF->setText(TagLib::String(name.UTF8String, TagLib::String::Type::UTF8));
        chapter->addEmbeddedFrame(eF);
        mpegFile->ID3v2Tag()->addFrame(chapter);
    }
    bool result = mpegFile->save();
    return result;
}

+ (nullable NSMutableDictionary *)getAudioProperties:(NSString *)path
{
    const char *filepath = path.UTF8String;
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return nil;
    }
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    TagLib::AudioProperties *audioProperties = fileRef.audioProperties();
    TagLib::FLAC::Properties *flacProps = dynamic_cast<TagLib::FLAC::Properties *>(fileRef.audioProperties());
    TagLib::RIFF::AIFF::Properties *aiffProps = dynamic_cast<TagLib::RIFF::AIFF::Properties *>(fileRef.audioProperties());
    TagLib::MP4::Properties *mp4Props = dynamic_cast<TagLib::MP4::Properties *>(fileRef.audioProperties());
    TagLib::RIFF::WAV::Properties *wavProps = dynamic_cast<TagLib::RIFF::WAV::Properties *>(fileRef.audioProperties());
    
    dictionary[AP_LENGTH] = [NSNumber numberWithInt:audioProperties->length()];
    dictionary[AP_BITRATE] = [NSNumber numberWithInt:audioProperties->bitrate()];
    dictionary[AP_SAMPLERATE] = [NSNumber numberWithInt:audioProperties->sampleRate()];
    if (flacProps) {
        dictionary[AP_BITSPERSAMPLE] = [NSNumber numberWithInt:flacProps->bitsPerSample()];
    }
    else if (aiffProps) {
        dictionary[AP_BITSPERSAMPLE] = [NSNumber numberWithInt:aiffProps->bitsPerSample()];
    }
    else if (mp4Props) {
        dictionary[AP_BITSPERSAMPLE] = [NSNumber numberWithInt:mp4Props->bitsPerSample()];
    }
    else if (wavProps) {
        dictionary[AP_BITSPERSAMPLE] = [NSNumber numberWithInt:wavProps->bitsPerSample()];
    }
    
    return dictionary;
}


+ (NSString *)detectFileType:(NSString *)path
{
    if (![path.pathExtension isEqualToString:@""]) {
        // NSLog(@"returning via extension %@", path.pathExtension);
        return [path.pathExtension lowercaseString];
    }
    return [TaglibWrapper detectStreamType:path];
}

+ (NSString *)detectStreamType:(NSString *)path
{
    const char *filepath = path.UTF8String;
    TagLib::FileStream *stream = new TagLib::FileStream(filepath);
    
    if (!stream->isOpen()) {
        NSLog(@"Unable to open FileStream: %@", path);
        delete stream;
        return nil;
    }
    const char *value = nil;
    
    if (TagLib::MPEG::File::isSupported(stream)) {
        value = "mp3";
    } else if (TagLib::MP4::File::isSupported(stream)) {
        value = "m4a";
    } else if (TagLib::RIFF::WAV::File::isSupported(stream)) {
        value = "wav";
    } else if (TagLib::RIFF::AIFF::File::isSupported(stream)) {
        value = "aiff";
    } else if (TagLib::FLAC::File:: isSupported(stream)) {
        value = "flac";
    }
    
    delete stream;
    
    if (value) {
        // NSLog(@"Returning stream file type: %s", value);
        return [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
    }
    return nil;
}

+ (NSString *)stringFromWchar:(const wchar_t *)charText
{
    //used ARC
    return [[NSString alloc] initWithBytes:charText length:wcslen(charText) * sizeof(*charText) encoding:NSUTF32LittleEndianStringEncoding];
}

+ (bool)setCover:(NSString *)path coverURL:(NSURL*)coverURL mimeType:(NSString*)mimeType
{
    const char *filepath = path.UTF8String;
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return NO;
    }
    
    NSString *fileType = [TaglibWrapper detectStreamType:path];
    if ([fileType isEqual: @"mp3"]) {
        TagLib::MPEG::File* mpegFile = dynamic_cast<TagLib::MPEG::File*>(fileRef.file());
        if (mpegFile && mpegFile->ID3v2Tag()) {
            NSData *data = [NSData dataWithContentsOfURL:coverURL];
            if (data != nil && [data length] > 0) {
                //--- need to remove any existing Picture first or the save doesn't actually work
                TagLib::ID3v2::FrameList frameList = mpegFile->ID3v2Tag()->frameListMap()["APIC"];
                TagLib::ID3v2::FrameList::Iterator it;
                for (it = frameList.begin(); it != frameList.end(); ++it) {
                    TagLib::ID3v2::AttachedPictureFrame *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
                    if(picture->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
                        mpegFile->ID3v2Tag()->removeFrame(picture);
                    }
                }
                
                TagLib::ID3v2::AttachedPictureFrame *picture = new TagLib::ID3v2::AttachedPictureFrame();
                TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                picture->setPicture(bv);
                picture->setMimeType(mimeType.UTF8String);
                picture->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
                
                TagLib::ID3v2::Tag *tag = mpegFile->ID3v2Tag();
                if (tag) {
                    tag->addFrame(picture);
                }
                return fileRef.save();
            }
        }
    }
    else if ([fileType isEqual: @"wav"]) {
        TagLib::RIFF::WAV::File* wavFile = dynamic_cast<TagLib::RIFF::WAV::File*>(fileRef.file());
        if (wavFile && wavFile->ID3v2Tag()) {
            NSData *data = [NSData dataWithContentsOfURL:coverURL];
            if (data != nil && [data length] > 0) {
                //--- need to remove any existing Picture first or the save doesn't actually work
                TagLib::ID3v2::FrameList frameList = wavFile->ID3v2Tag()->frameListMap()["APIC"];
                TagLib::ID3v2::FrameList::Iterator it;
                for (it = frameList.begin(); it != frameList.end(); ++it) {
                    TagLib::ID3v2::AttachedPictureFrame *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
                    if(picture->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
                        wavFile->ID3v2Tag()->removeFrame(picture);
                    }
                }
                
                TagLib::ID3v2::AttachedPictureFrame *picture = new TagLib::ID3v2::AttachedPictureFrame();
                TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                picture->setPicture(bv);
                picture->setMimeType(mimeType.UTF8String);
                picture->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
                
                TagLib::ID3v2::Tag *tag = wavFile->ID3v2Tag();
                if (tag) {
                    tag->addFrame(picture);
                }
                return fileRef.save();
            }
        }
    }
    else if ([fileType isEqual: @"aiff"]) {
        TagLib::RIFF::AIFF::File* aiffFile = dynamic_cast<TagLib::RIFF::AIFF::File*>(fileRef.file());
        if (aiffFile && aiffFile->tag()) {
            NSData *data = [NSData dataWithContentsOfURL:coverURL];
            if (data != nil && [data length] > 0) {
                //--- need to remove any existing Picture first or the save doesn't actually work
                TagLib::ID3v2::FrameList frameList = aiffFile->tag()->frameListMap()["APIC"];
                TagLib::ID3v2::FrameList::Iterator it;
                for (it = frameList.begin(); it != frameList.end(); ++it) {
                    TagLib::ID3v2::AttachedPictureFrame *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
                    if (picture->type() == TagLib::ID3v2::AttachedPictureFrame::Other) {
                        aiffFile->tag()->removeFrame(picture);
                    }
                }
                
                TagLib::ID3v2::AttachedPictureFrame *picture = new TagLib::ID3v2::AttachedPictureFrame();
                TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                picture->setPicture(bv);
                picture->setMimeType(mimeType.UTF8String);
                picture->setType(TagLib::ID3v2::AttachedPictureFrame::Other);
                
                TagLib::ID3v2::Tag *tag = aiffFile->tag();
                if (tag) {
                    tag->addFrame(picture);
                }
                return fileRef.save();
            }
        }
    }
    else if ([fileType isEqual: @"flac"]) {
        TagLib::FLAC::File* flacFile = dynamic_cast<TagLib::FLAC::File*>(fileRef.file());
        if (flacFile) {
            NSData *data = [NSData dataWithContentsOfURL:coverURL];
            if (data != nil && [data length] > 0) {
                TagLib::FLAC::Picture *picture = new TagLib::FLAC::Picture;
                picture->setType(TagLib::FLAC::Picture::FrontCover);
                picture->setMimeType(mimeType.UTF8String);
                TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                picture->setData(bv);
                
                flacFile->removePictures();
                flacFile->addPicture(picture);
                
                return fileRef.save();
            }
        }
    }
    else if ([fileType isEqual: @"m4a"]) {
        TagLib::MP4::File* m4aFile = dynamic_cast<TagLib::MP4::File*>(fileRef.file());
        if (m4aFile) {
            NSData *data = [NSData dataWithContentsOfURL:coverURL];
            if (data != nil && [data length] > 0) {
                int format = TagLib::MP4::AtomDataType::TypeJPEG;
                if ([mimeType isEqual:@"image/jpeg"] || [mimeType isEqual:@"image/jpg"]) {
                    format = TagLib::MP4::AtomDataType::TypeJPEG;
                }
                else if ([mimeType isEqual:@"image/png"]) {
                    format = TagLib::MP4::AtomDataType::TypePNG;
                }
                else if ([mimeType isEqual:@"image/gif"]) {
                    format = TagLib::MP4::AtomDataType::TypeGIF;
                }
                else if ([mimeType isEqual:@"image/bmp"]) {
                    format = TagLib::MP4::AtomDataType::TypeBMP;
                }
                
                TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                TagLib::MP4::CoverArt coverArt((TagLib::MP4::CoverArt::Format)format, bv);
                TagLib::MP4::CoverArtList coverArtList;
                
                // append instance
                coverArtList.append(coverArt);
                
                // convert to item
                TagLib::MP4::Item coverItem(coverArtList);
                
                m4aFile->tag()->setItem("covr", coverItem);
                return fileRef.save();
            }
        }
    }
    
    return NO;
}

+ (bool)setCovers:(NSString *)path images:(NSDictionary *)images mimeTypes:(NSDictionary *)mimeTypes imagesToRemove:(NSArray *)imagesToRemove
{
    const char *filepath = path.UTF8String;
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return NO;
    }
    
    NSMutableSet *allKeys = [NSMutableSet setWithArray:[images allKeys]];
    [allKeys addObjectsFromArray:imagesToRemove];
    NSString *fileType = [TaglibWrapper detectStreamType:path];
    if ([fileType isEqual: @"mp3"]) {
        TagLib::MPEG::File* mpegFile = dynamic_cast<TagLib::MPEG::File*>(fileRef.file());
        if (mpegFile && mpegFile->ID3v2Tag()) {
            NSNumber *key;
            for (key in allKeys) {
                NSData *data = images[key];
                CoverArtType type = [key longValue];
                NSString *mimeType = mimeTypes[key];
                
                //--- need to remove any existing Picture first or the save doesn't actually work
                if ((data != nil && [data length] > 0) || [imagesToRemove containsObject:key]) {
                    TagLib::ID3v2::FrameList frameList = mpegFile->ID3v2Tag()->frameListMap()["APIC"];
                    TagLib::ID3v2::FrameList::Iterator it;
                    for (it = frameList.begin(); it != frameList.end(); ++it) {
                        TagLib::ID3v2::AttachedPictureFrame *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
                        if(picture->type() == [TaglibWrapper attachedPictureFrameType:type]) {
                            mpegFile->ID3v2Tag()->removeFrame(picture);
                        }
                    }
                }
                    
                if (data != nil && [data length] > 0) {
                    TagLib::ID3v2::AttachedPictureFrame *picture = new TagLib::ID3v2::AttachedPictureFrame();
                    TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                    picture->setPicture(bv);
                    picture->setMimeType(mimeType.UTF8String);
                    picture->setType([TaglibWrapper attachedPictureFrameType:type]);
                    
                    TagLib::ID3v2::Tag *tag = mpegFile->ID3v2Tag();
                    if (tag) {
                        tag->addFrame(picture);
                    }
                }
            }
            return fileRef.save();
        }
    }
    else if ([fileType isEqual: @"wav"]) {
        TagLib::RIFF::WAV::File* wavFile = dynamic_cast<TagLib::RIFF::WAV::File*>(fileRef.file());
        if (wavFile && wavFile->ID3v2Tag()) {
            NSNumber *key;
            for (key in allKeys) {
                NSData *data = images[key];
                CoverArtType type = [key longValue];
                NSString *mimeType = mimeTypes[key];

                //--- need to remove any existing Picture first or the save doesn't actually work
                if ((data != nil && [data length] > 0) || [imagesToRemove containsObject:key]) {
                    TagLib::ID3v2::FrameList frameList = wavFile->ID3v2Tag()->frameListMap()["APIC"];
                    TagLib::ID3v2::FrameList::Iterator it;
                    for (it = frameList.begin(); it != frameList.end(); ++it) {
                        TagLib::ID3v2::AttachedPictureFrame *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
                        if(picture->type() == [TaglibWrapper attachedPictureFrameType:type]) {
                            wavFile->ID3v2Tag()->removeFrame(picture);
                        }
                    }
                }
                    
                if (data != nil && [data length] > 0) {
                    TagLib::ID3v2::AttachedPictureFrame *picture = new TagLib::ID3v2::AttachedPictureFrame();
                    TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                    picture->setPicture(bv);
                    picture->setMimeType(mimeType.UTF8String);
                    picture->setType([TaglibWrapper attachedPictureFrameType:type]);
                    
                    TagLib::ID3v2::Tag *tag = wavFile->ID3v2Tag();
                    if (tag) {
                        tag->addFrame(picture);
                    }
                }
            }
            return fileRef.save();
        }
    }
    else if ([fileType isEqual: @"aiff"]) {
        TagLib::RIFF::AIFF::File* aiffFile = dynamic_cast<TagLib::RIFF::AIFF::File*>(fileRef.file());
        if (aiffFile && aiffFile->tag()) {
            NSNumber *key;
            for (key in allKeys) {
                NSData *data = images[key];
                CoverArtType type = [key longValue];
                NSString *mimeType = mimeTypes[key];

                //--- need to remove any existing Picture first or the save doesn't actually work
                if ((data != nil && [data length] > 0) || [imagesToRemove containsObject:key]) {
                    TagLib::ID3v2::FrameList frameList = aiffFile->tag()->frameListMap()["APIC"];
                    TagLib::ID3v2::FrameList::Iterator it;
                    for (it = frameList.begin(); it != frameList.end(); ++it) {
                        TagLib::ID3v2::AttachedPictureFrame *picture = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(*it);
                        if(picture->type() == [TaglibWrapper attachedPictureFrameType:type]) {
                            aiffFile->tag()->removeFrame(picture);
                        }
                    }
                }
                
                if (data != nil && [data length] > 0) {
                    TagLib::ID3v2::AttachedPictureFrame *picture = new TagLib::ID3v2::AttachedPictureFrame();
                    TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                    picture->setPicture(bv);
                    picture->setMimeType(mimeType.UTF8String);
                    picture->setType([TaglibWrapper attachedPictureFrameType:type]);
                    
                    TagLib::ID3v2::Tag *tag = aiffFile->tag();
                    if (tag) {
                        tag->addFrame(picture);
                    }
                }
            }
            return fileRef.save();
        }
    }
    else if ([fileType isEqual: @"flac"]) {
        TagLib::FLAC::File* flacFile = dynamic_cast<TagLib::FLAC::File*>(fileRef.file());
        if (flacFile) {
            
            NSNumber *key;
            for (key in allKeys) {
                NSData *data = images[key];
                CoverArtType type = [key longValue];
                NSString *mimeType = mimeTypes[key];
                
                //--- need to remove any existing Picture first or the save doesn't actually work
                if ((data != nil && [data length] > 0) || [imagesToRemove containsObject:key]) {
                    NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
                    TagLib::FLAC::File *flacFile = dynamic_cast<TagLib::FLAC::File *>(fileRef.file());
                    const TagLib::List<TagLib::FLAC::Picture*> picturelist = flacFile->pictureList();
                    for(TagLib::List<TagLib::FLAC::Picture*>::ConstIterator it = picturelist.begin(); it != picturelist.end(); it++) {
                        TagLib::FLAC::Picture *pictureToRemove = (*it);
                        if (pictureToRemove) {
                            if (pictureToRemove->type() == type) {
                                flacFile->removePicture(pictureToRemove);
                            }
                        }
                    }
                }
                
                if (data != nil && [data length] > 0) {
                    TagLib::FLAC::Picture *picture = new TagLib::FLAC::Picture;
                    picture->setType([TaglibWrapper flacPictureType:type]);
                    picture->setMimeType(mimeType.UTF8String);
                    TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                    picture->setData(bv);
                    
                    flacFile->addPicture(picture);
                }
            }
            return fileRef.save();
        }
    }
    else if ([fileType isEqual: @"m4a"]) {
        TagLib::MP4::File* m4aFile = dynamic_cast<TagLib::MP4::File*>(fileRef.file());
        if (m4aFile) {
            TagLib::MP4::CoverArtList coverArtList;
            
            NSNumber *key;
            for (key in allKeys) {
                NSData *data = images[key];
                CoverArtType type = [key longValue];
                NSString *mimeType = mimeTypes[key];
                if (data != nil && [data length] > 0) {
                    int format = TagLib::MP4::AtomDataType::TypeJPEG;
                    if ([mimeType isEqual:@"image/jpeg"] || [mimeType isEqual:@"image/jpg"]) {
                        format = TagLib::MP4::AtomDataType::TypeJPEG;
                    }
                    else if ([mimeType isEqual:@"image/png"]) {
                        format = TagLib::MP4::AtomDataType::TypePNG;
                    }
                    else if ([mimeType isEqual:@"image/gif"]) {
                        format = TagLib::MP4::AtomDataType::TypeGIF;
                    }
                    else if ([mimeType isEqual:@"image/bmp"]) {
                        format = TagLib::MP4::AtomDataType::TypeBMP;
                    }
                    
                    TagLib::ByteVector bv = TagLib::ByteVector((const char *)[data bytes], (int)[data length]);
                    TagLib::MP4::CoverArt coverArt((TagLib::MP4::CoverArt::Format)format, bv);
                    
                    // append instance
                    coverArtList.append(coverArt);
                }
            }

            // convert to item
            TagLib::MP4::Item coverItem(coverArtList);

            if (imagesToRemove.count > 0) {
                m4aFile->tag()->removeItem("covr");
            }
            if (coverArtList.size() > 0) {
                m4aFile->tag()->setItem("covr", coverItem);
            }
            return fileRef.save();
        }
    }
    
    return NO;
}

+ (nullable NSDictionary *)coverArtData:(NSString *)path
{
    const char *filepath = path.UTF8String;
    TagLib::FileRef fileRef(path.UTF8String);
    if (fileRef.isNull()) {
        return nil;
    }
    
    NSString *fileType = [TaglibWrapper detectStreamType:path];
    if ([fileType isEqual: @"flac"]) {
        NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
        TagLib::FLAC::File *flacFile = dynamic_cast<TagLib::FLAC::File *>(fileRef.file());
        const TagLib::List<TagLib::FLAC::Picture*> picturelist = flacFile->pictureList();
        for(TagLib::List<TagLib::FLAC::Picture*>::ConstIterator it = picturelist.begin();
            it != picturelist.end();
            it++) {
            TagLib::FLAC::Picture *picture = (*it);
            if (picture) {
                CoverArtType type = [TaglibWrapper flacCoverArtType:picture->type()];
                pictures[[NSNumber numberWithLong:type]] = [NSData dataWithBytes:picture->data().data() length:picture->data().size()];
            }
        }
        return pictures;
    }
    else if ([fileType isEqual: @"mp3"]) {
        NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
        TagLib::MPEG::File* mpegFile = dynamic_cast<TagLib::MPEG::File*>(fileRef.file());
        if (mpegFile && mpegFile->ID3v2Tag()) {
            TagLib::ID3v2::FrameList apic_frames = mpegFile->ID3v2Tag()->frameListMap()["APIC"];
            if (apic_frames.isEmpty()) {
                return nil;
            }
            
            for(TagLib::List<TagLib::ID3v2::Frame*>::ConstIterator it = apic_frames.begin();
                it != apic_frames.end();
                it++) {
                TagLib::ID3v2::AttachedPictureFrame* picture = static_cast<TagLib::ID3v2::AttachedPictureFrame*>(*it);
                if (picture != NULL) {
                    CoverArtType type = [TaglibWrapper coverArtType:picture->type()];
                    pictures[[NSNumber numberWithLong:type]] = [NSData dataWithBytes:picture->picture().data() length:picture->picture().size()];
                }
            }
        }
        return pictures;
    }
    else if ([fileType isEqual: @"wav"]) {
        NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
        TagLib::RIFF::WAV::File* wavFile = dynamic_cast<TagLib::RIFF::WAV::File*>(fileRef.file());
        if (wavFile && wavFile->ID3v2Tag()) {
            TagLib::ID3v2::FrameList apic_frames = wavFile->ID3v2Tag()->frameListMap()["APIC"];
            if (apic_frames.isEmpty()) {
                return nil;
            }
            
            for(TagLib::List<TagLib::ID3v2::Frame*>::ConstIterator it = apic_frames.begin();
                it != apic_frames.end();
                it++) {
                TagLib::ID3v2::AttachedPictureFrame* picture = static_cast<TagLib::ID3v2::AttachedPictureFrame*>(*it);
                if (picture != NULL) {
                    CoverArtType type = [TaglibWrapper coverArtType:picture->type()];
                    pictures[[NSNumber numberWithLong:type]] = [NSData dataWithBytes:picture->picture().data() length:picture->picture().size()];
                }
            }
        }
        return pictures;
    }
    else if ([fileType isEqual: @"aiff"]) {
        NSMutableDictionary *pictures = [NSMutableDictionary dictionary];
        TagLib::RIFF::AIFF::File* aiffFile = dynamic_cast<TagLib::RIFF::AIFF::File*>(fileRef.file());
        if (aiffFile && aiffFile->tag()) {
            TagLib::ID3v2::FrameList apic_frames = aiffFile->tag()->frameListMap()["APIC"];
            if (apic_frames.isEmpty()) {
                return nil;
            }
            
            for(TagLib::List<TagLib::ID3v2::Frame*>::ConstIterator it = apic_frames.begin();
                it != apic_frames.end();
                it++) {
                TagLib::ID3v2::AttachedPictureFrame* picture = static_cast<TagLib::ID3v2::AttachedPictureFrame*>(*it);
                if (picture != NULL) {
                    CoverArtType type = [TaglibWrapper coverArtType:picture->type()];
                    pictures[[NSNumber numberWithLong:type]] = [NSData dataWithBytes:picture->picture().data() length:picture->picture().size()];
                }
            }
        }
        return pictures;
    }
    else if ([fileType isEqual: @"m4a"]) {
        TagLib::MP4::File* m4aFile = dynamic_cast<TagLib::MP4::File*>(fileRef.file());
        if (m4aFile) {
            TagLib::MP4::Tag* tag = m4aFile->tag();
            TagLib::MP4::Item coverItem = tag->item("covr");
            const TagLib::MP4::CoverArtList& art_list = coverItem.toCoverArtList();
            
            if (!art_list.isEmpty()) {
                // Just take the first one for now
                const TagLib::MP4::CoverArt& art = art_list.front();
                CoverArtType type = other;
                return [NSDictionary dictionaryWithObject:[NSData dataWithBytes:art.data().data() length:art.data().size()] forKey:[NSNumber numberWithLong:type]];
            }
        }
    }
    
    return nil;
}

+ (CoverArtType)coverArtType:(TagLib::ID3v2::AttachedPictureFrame::Type)type {
    return static_cast<CoverArtType>(type);
}

+ (TagLib::ID3v2::AttachedPictureFrame::Type)attachedPictureFrameType:(CoverArtType)type {
    return static_cast<TagLib::ID3v2::AttachedPictureFrame::Type>(type);
}

+ (CoverArtType)flacCoverArtType:(TagLib::FLAC::Picture::Type)type {
    return static_cast<CoverArtType>(type);
}

+ (TagLib::FLAC::Picture::Type)flacPictureType:(CoverArtType)type {
    return static_cast<TagLib::FLAC::Picture::Type>(type);
}

@end

/**
 // see: http://id3.org/id3v2.4.0-frames
 const char *frameTranslation[][2] = {
 // Text information frames
 { "TALB", "ALBUM"},
 { "TBPM", "BPM" },
 { "TCOM", "COMPOSER" },
 { "TCON", "GENRE" },
 { "TCOP", "COPYRIGHT" },
 { "TDEN", "ENCODINGTIME" },
 { "TDLY", "PLAYLISTDELAY" },
 { "TDOR", "ORIGINALDATE" },
 { "TDRC", "DATE" },
 // { "TRDA", "DATE" }, // id3 v2.3, replaced by TDRC in v2.4
 // { "TDAT", "DATE" }, // id3 v2.3, replaced by TDRC in v2.4
 // { "TYER", "DATE" }, // id3 v2.3, replaced by TDRC in v2.4
 // { "TIME", "DATE" }, // id3 v2.3, replaced by TDRC in v2.4
 { "TDRL", "RELEASEDATE" },
 { "TDTG", "TAGGINGDATE" },
 { "TENC", "ENCODEDBY" },
 { "TEXT", "LYRICIST" },
 { "TFLT", "FILETYPE" },
 //{ "TIPL", "INVOLVEDPEOPLE" }, handled separately
 { "TIT1", "CONTENTGROUP" },
 { "TIT2", "TITLE"},
 { "TIT3", "SUBTITLE" },
 { "TKEY", "INITIALKEY" },
 { "TLAN", "LANGUAGE" },
 { "TLEN", "LENGTH" },
 //{ "TMCL", "MUSICIANCREDITS" }, handled separately
 { "TMED", "MEDIA" },
 { "TMOO", "MOOD" },
 { "TOAL", "ORIGINALALBUM" },
 { "TOFN", "ORIGINALFILENAME" },
 { "TOLY", "ORIGINALLYRICIST" },
 { "TOPE", "ORIGINALARTIST" },
 { "TOWN", "OWNER" },
 { "TPE1", "ARTIST"},
 { "TPE2", "ALBUMARTIST" }, // id3's spec says 'PERFORMER', but most programs use 'ALBUMARTIST'
 { "TPE3", "CONDUCTOR" },
 { "TPE4", "REMIXER" }, // could also be ARRANGER
 { "TPOS", "DISCNUMBER" },
 { "TPRO", "PRODUCEDNOTICE" },
 { "TPUB", "LABEL" },
 { "TRCK", "TRACKNUMBER" },
 { "TRSN", "RADIOSTATION" },
 { "TRSO", "RADIOSTATIONOWNER" },
 { "TSOA", "ALBUMSORT" },
 { "TSOP", "ARTISTSORT" },
 { "TSOT", "TITLESORT" },
 { "TSO2", "ALBUMARTISTSORT" }, // non-standard, used by iTunes
 { "TSRC", "ISRC" },
 { "TSSE", "ENCODING" },
 // URL frames
 { "WCOP", "COPYRIGHTURL" },
 { "WOAF", "FILEWEBPAGE" },
 { "WOAR", "ARTISTWEBPAGE" },
 { "WOAS", "AUDIOSOURCEWEBPAGE" },
 { "WORS", "RADIOSTATIONWEBPAGE" },
 { "WPAY", "PAYMENTWEBPAGE" },
 { "WPUB", "PUBLISHERWEBPAGE" },
 //{ "WXXX", "URL"}, handled specially
 // Other frames
 { "COMM", "COMMENT" },
 //{ "USLT", "LYRICS" }, handled specially
 // Apple iTunes proprietary frames
 { "PCST", "PODCAST" },
 { "TCAT", "PODCASTCATEGORY" },
 { "TDES", "PODCASTDESC" },
 { "TGID", "PODCASTID" },
 { "WFED", "PODCASTURL" },
 { "MVNM", "MOVEMENTNAME" },
 { "MVIN", "MOVEMENTNUMBER" },
 };
 **/
