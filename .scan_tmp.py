import struct, hashlib, os
ROOT = 'D:/Projects/Github/yarp_device_zte_P725A02'
p = ROOT + '/prebuilt/kernel'
d = open(p,'rb').read()
print('size', len(d))
print('first16', d[:16].hex())
print('magic u32', hex(struct.unpack_from('<I', d, 0)[0]))
idx=[]; i=0
while True:
    j = d.find(b'\xd0\x0d\xfe\xed', i)
    if j<0: break
    idx.append(j); i=j+1
print('dtb magic count', len(idx))
print('dtb offsets first20', idx[:20])
print('dtb offsets last5', idx[-5:])
for j in idx[:8]:
    tot, os_, ost, rsv, ver, lv = struct.unpack_from('>IIIIII', d, j+4)
    print('dtb@%d totalsize=%d end=%d ver=%x lastver=%x' % (j, tot, j+tot, ver, lv))
print('sha256 prebuilt/kernel', hashlib.sha256(d).hexdigest())
for q in ['prebuilt/dtb.img','prebuilt/dtbo.img','stock/boot/split_img/boot.img-dtb','stock/boot/split_img/boot.img-kernel','stock/boot/split_img/boot.img-ramdisk.cpio.gz']:
    pp = ROOT + '/' + q
    dd = open(pp,'rb').read()
    print(q, len(dd), hashlib.sha256(dd).hexdigest(), dd[:8].hex())