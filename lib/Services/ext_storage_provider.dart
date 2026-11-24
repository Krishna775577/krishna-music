/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ignore: avoid_classes_with_only_static_members
class ExtStorageProvider {
  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) return true;
    return await permission.request() == PermissionStatus.granted;
  }

  // Scoped-storage compatible default location. On Android 10+,
  // downloads are stored in the app-owned Music directory, without
  // requesting access to unrelated files on the user's phone.
  // Existing user files are never deleted or migrated here.
  static Future<String?> getExtStorage({
    required String dirName,
    required bool writeAccess,
  }) async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      final String fullPath;
      if (sdk >= 29) {
        fullPath = '${directory.path}/$dirName';
      } else {
        if (!await requestPermission(Permission.storage)) {
          return null;
        }
        final root = directory.path.split('/Android/').first;
        fullPath = '$root/$dirName';
      }
      final target = Directory(fullPath);
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target.path;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/${dirName.replaceAll('BlackHole/', '')}';
    }
    final directory = await getDownloadsDirectory();
    return directory == null ? null : '${directory.path}/$dirName';
  }
}
