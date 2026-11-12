#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <fcntl.h>
int main(void){
  struct stat st; int pid=getpid();
  FILE*f=fopen("/proc/mounts","r"); char l[200]; int root_ext4=0;
  while(f&&fgets(l,sizeof l,f)) if(l[0]=='/'&&strstr(l," / ext4 ")) root_ext4=1;
  if(f)fclose(f);
  int c=open("/dev/console",O_WRONLY);
  char m[240]; int n=snprintf(m,sizeof m,"EKU-TEST: yeni rootfs init calisiyor pid=%d root_ext4=%d marker=%s\n",pid,root_ext4,stat("/EKU_MARKER_SYSTEM",&st)==0?"SYSTEM":"?");
  write(c,m,n); sync(); reboot(RB_POWER_OFF); for(;;)pause(); }
