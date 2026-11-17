import { CameraView, useCameraPermissions } from 'expo-camera';
import { router } from 'expo-router';
import React, { useEffect, useRef, useState } from 'react';
import { View } from 'react-native';

import { webLinkCodeFrom } from '@/domain/models';
import { IconButton } from '@/ui/Buttons';
import { AppBar, goBack } from '@/ui/Scaffold';
import { T } from '@/ui/Text';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

/** The camera, pointed at the QR code on the website. The first FPLboardman code it sees opens its approval page. */
export default function ScanBrowserCodeScreen() {
  const insets = useSafeAreaInsets();
  const [permission, requestPermission] = useCameraPermissions();
  const handled = useRef(false);
  const [notOurs, setNotOurs] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (permission && !permission.granted && permission.canAskAgain) requestPermission();
  }, [permission, requestPermission]);

  const onScanned = ({ data }: { data: string }) => {
    if (handled.current) return;
    const code = webLinkCodeFrom(data);
    if (code) {
      handled.current = true;
      router.replace(`/link/${code}`);
      return;
    }
    if (notOurs == null) setNotOurs('That is not an FPLboardman code. Scan the code on the FPLboardman website.');
  };

  const denied = permission != null && !permission.granted && !permission.canAskAgain;
  const problem = denied
    ? 'FPLboardman needs the camera to scan the code. Allow camera access for FPLboardman in your phone settings, then try again.'
    : failed
      ? 'The camera could not be started. Close other apps using it and try again.'
      : null;

  return (
    <View style={{ flex: 1, backgroundColor: '#000000', paddingTop: insets.top }}>
      <View>
        <AppBarWhite />
      </View>
      <View style={{ flex: 1 }}>
        {problem ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32 }}>
            <T center color="#FFFFFF" style={{ lineHeight: 20 }}>
              {problem}
            </T>
          </View>
        ) : permission?.granted ? (
          <CameraView
            style={{ flex: 1 }}
            facing="back"
            barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
            onBarcodeScanned={onScanned}
            onMountError={() => setFailed(true)}
          />
        ) : null}
        {/* A square to aim with. */}
        <View pointerEvents="none" style={{ position: 'absolute', top: 0, bottom: 0, left: 0, right: 0, alignItems: 'center', justifyContent: 'center' }}>
          <View style={{ width: 250, height: 250, borderWidth: 3, borderColor: '#FFFFFF', borderRadius: 24 }} />
        </View>
        <View style={{ position: 'absolute', left: 24, right: 24, bottom: 48 + insets.bottom }}>
          <T center color="#FFFFFF" style={{ fontSize: 15, lineHeight: 21 }}>
            {notOurs ?? 'Open the FPLboardman website on your computer and point your phone at the code it shows.'}
          </T>
        </View>
      </View>
    </View>
  );
}

function AppBarWhite() {
  return (
    <AppBar
      leading={<IconButton icon="arrow_back" tooltip="Back" color="#FFFFFF" onPress={() => goBack('/linked-browsers')} />}
      title={
        <T v="titleLarge" w={800} color="#FFFFFF" numberOfLines={1}>
          Scan the website code
        </T>
      }
    />
  );
}
