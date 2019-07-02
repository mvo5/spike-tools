/**
gcc -shared -fPIC -o no-udev.so UdevDisableLib.c -ldl
 */

#define _GNU_SOURCE 1

int dm_udev_wait() {
  return(0);
}
