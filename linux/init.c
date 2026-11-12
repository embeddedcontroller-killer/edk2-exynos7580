/*
 * J7 init + tiny framebuffer GUI (static, no dependencies).
 * Keys (read from GPIO via /dev/mem, bank gpa2 of pinctrl@139B0000 on Exynos 7580):
 *   vol up = gpa2-0, vol down = gpa2-1, power = gpa2-7.   Polarity is auto-detected at start.
 * If the GPIO page cannot be mapped the GUI cycles through its screens on its own.
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>
#include <sys/utsname.h>
#include <linux/fb.h>
#include <dirent.h>
#include <errno.h>
#include <stdarg.h>
#include <strings.h>
#include <sys/syscall.h>
#include "font8x16.h"

#define PIO_BASE   0x139B0000UL
#define BANK_OFF   0x040
#define DAT_OFF    0x004
#define K_UP   (1u << 0)
#define K_DOWN (1u << 1)
#define K_PWR  (1u << 7)

static uint8_t *fbmem;
static uint32_t *back;
static int W, H, STRIDE;                 /* STRIDE in bytes */
static int ro, go, bo;                   /* colour offsets */
static volatile uint32_t *gpio_dat;
static uint32_t idle_state;

static uint32_t rgb(int r, int g, int b) { return ((uint32_t)r << ro) | ((uint32_t)g << go) | ((uint32_t)b << bo); }

static void rect(int x, int y, int w, int h, uint32_t c)
{
	if (x < 0) { w += x; x = 0; }
	if (y < 0) { h += y; y = 0; }
	if (x + w > W) w = W - x;
	if (y + h > H) h = H - y;
	for (int j = 0; j < h; j++) {
		uint32_t *p = back + (size_t)(y + j) * W + x;
		for (int i = 0; i < w; i++) p[i] = c;
	}
}

static void text(int x, int y, int s, uint32_t c, const char *str)
{
	for (; *str; str++, x += 8 * s) {
		const unsigned char *g = &font8x16[(unsigned char)*str * 16];
		for (int r = 0; r < 16; r++)
			for (int b = 0; b < 8; b++)
				if (g[r] & (0x80 >> b)) rect(x + b * s, y + r * s, s, s, c);
	}
}

static void flip(void)
{
	for (int y = 0; y < H; y++) memcpy(fbmem + (size_t)y * STRIDE, back + (size_t)y * W, (size_t)W * 4);
}

static uint32_t read_keys(void)
{
	if (!gpio_dat) return 0;
	return (*gpio_dat ^ idle_state) & (K_UP | K_DOWN | K_PWR);   /* bit set = pressed */
}

static void msleep(int ms) { struct timespec t = { ms / 1000, (ms % 1000) * 1000000L }; nanosleep(&t, NULL); }

static double uptime_s(void) { struct sysinfo si; sysinfo(&si); return (double)si.uptime; }

static void header(const char *title)
{
	rect(0, 0, W, H, rgb(16, 20, 40));
	rect(0, 0, W, 110, rgb(40, 60, 140));
	text(24, 24, 4, rgb(255, 255, 255), title);
	char b[64]; int up = (int)uptime_s();
	snprintf(b, sizeof b, "uptime %02d:%02d", up / 60, up % 60);
	text(24, 82, 1, rgb(200, 210, 255), b);
}

static const char *items[] = { "1  Sistem bilgisi", "2  Renk testi", "3  Animasyon", "4  Yeniden baslat" };
#define NITEMS 4

static void screen_menu(int sel, int keys_ok)
{
	header("Galaxy J7 - Linux");
	for (int i = 0; i < NITEMS; i++) {
		int y = 180 + i * 150;
		rect(40, y, W - 80, 120, i == sel ? rgb(70, 130, 255) : rgb(36, 44, 80));
		text(70, y + 36, 3, rgb(255, 255, 255), items[i]);
	}
	text(40, H - 130, 2, rgb(170, 180, 220), keys_ok ? "Vol: sec   Power: ac" : "Tus okunamadi: otomatik demo");
	text(40, H - 90, 2, rgb(120, 130, 170), "EDK2 + Linux 6.12 (EFI stub)");
}

static void screen_info(void)
{
	struct utsname u; struct sysinfo si; char b[128]; long memkb = 0;
	uname(&u); sysinfo(&si);
	FILE *f = fopen("/proc/meminfo", "r");
	if (f) { while (fgets(b, sizeof b, f)) if (sscanf(b, "MemTotal: %ld kB", &memkb) == 1) break; fclose(f); }
	header("Sistem bilgisi");
	int y = 150;
	snprintf(b, sizeof b, "%s %s", u.sysname, u.release); text(30, y, 3, rgb(255, 255, 255), b); y += 70;
	snprintf(b, sizeof b, "mimari: %s", u.machine);       text(30, y, 3, rgb(255, 255, 255), b); y += 70;
	snprintf(b, sizeof b, "RAM: %ld MB", memkb / 1024);    text(30, y, 3, rgb(255, 255, 255), b); y += 70;
	snprintf(b, sizeof b, "CPU online: %ld", sysconf(_SC_NPROCESSORS_ONLN)); text(30, y, 3, rgb(255, 255, 255), b); y += 70;
	snprintf(b, sizeof b, "ekran: %dx%d", W, H);          text(30, y, 3, rgb(255, 255, 255), b); y += 70;
	snprintf(b, sizeof b, "yuk: %lu.%02lu", si.loads[0] >> 16, ((si.loads[0] & 0xffff) * 100) >> 16);
	text(30, y, 3, rgb(255, 255, 255), b);
	y += 70;
	{ int ni = 0; FILE *g = fopen("/proc/bus/input/devices", "r");
	  if (g) { while (fgets(b, sizeof b, g)) if (!strncmp(b, "N: Name=", 8)) ni++; fclose(g); }
	  snprintf(b, sizeof b, "giris aygiti: %d (dokunmatik icin surucu gerek)", ni); text(30, y, 2, rgb(255, 220, 120), b); }
	text(30, H - 60, 2, rgb(170, 180, 220), "Power: geri");
}

static void screen_colors(void)
{
	static const int cs[8][3] = {{255,255,255},{255,255,0},{0,255,255},{0,255,0},{255,0,255},{255,0,0},{0,0,255},{0,0,0}};
	for (int i = 0; i < 8; i++) rect(i * (W / 8), 0, W / 8 + 1, H - 220, rgb(cs[i][0], cs[i][1], cs[i][2]));
	for (int x = 0; x < W; x++) { int v = x * 255 / W; rect(x, H - 220, 1, 110, rgb(v, v, v)); rect(x, H - 110, 1, 110, rgb(v, 255 - v, 128)); }
}

static void screen_anim(int t)
{
	header("Animasyon");
	int bx = 40 + (t * 9) % (2 * (W - 200));  if (bx > W - 160) bx = 2 * (W - 200) - bx + 80;
	int by = 200 + (t * 7) % (2 * (H - 500)); if (by > H - 300) by = 2 * (H - 500) - by + 200;
	rect(bx, by, 120, 120, rgb(255, 160, 40));
	int pw = (t * 5) % (W - 80);
	rect(40, H - 120, W - 80, 40, rgb(36, 44, 80));
	rect(40, H - 120, pw, 40, rgb(70, 220, 120));
	text(30, H - 60, 2, rgb(170, 180, 220), "Power: geri");
}

static void logmsg(const char *s) { int fd = open("/dev/console", O_WRONLY); if (fd >= 0) { write(fd, s, strlen(s)); close(fd); } }

/* ------------------------------------------------------------------------------------------
 * Rootfs hand-off.  Active only when the kernel command line has  eku.root=...
 *   eku.root=auto               first partition named ROOTFS, LINUX, USERDATA, SYSTEM, CACHE or
 *                               HIDDEN (GPT PARTNAME, case-insensitive) that holds a usable init
 *   eku.root=PARTNAME=USERDATA  only that partition name
 *   eku.root=/dev/mmcblk0p21    only that device
 *   eku.init=/sbin/init         init path inside the rootfs (default: probe a few known ones)
 * Kernel modules listed (one per line, load order) in /lib/modules/eku-modules.txt are loaded
 * first (eMMC driver); missing files are skipped.  A partition is accepted only if it mounts as
 * ext4 AND contains an init, so Android's /system or /data are never taken for a rootfs.
 * If anything fails the GUI simply starts as usual.
 * ---------------------------------------------------------------------------------------- */
static char slog[22][100];
static int nslog;
static char cmdline[2048];

static void status(const char *fmt, ...)
{
	char l[100]; va_list ap;
	va_start(ap, fmt); vsnprintf(l, sizeof l, fmt, ap); va_end(ap);
	if (nslog == 22) { memmove(slog[0], slog[1], sizeof slog - sizeof slog[0]); nslog--; }
	snprintf(slog[nslog++], sizeof slog[0], "%s", l);
	char m[130]; snprintf(m, sizeof m, "[j7init] %s\n", l); logmsg(m);
	if (!back) return;
	rect(0, 0, W, H, rgb(0, 0, 0));
	header("ProjectEku Linux 6.12");
	for (int i = 0; i < nslog; i++) text(16, 130 + i * 40, 2, rgb(255, 255, 255), slog[i]);
	flip();
}

static int cmd_get(const char *key, char *out, size_t n)
{
	size_t kl = strlen(key); const char *p = cmdline;
	while ((p = strstr(p, key))) {
		if ((p == cmdline || p[-1] == ' ') && p[kl] == '=') {
			p += kl + 1; size_t i = 0;
			while (*p && *p != ' ' && *p != '\n' && i + 1 < n) out[i++] = *p++;
			out[i] = 0; return 1;
		}
		p += kl;
	}
	return 0;
}

static int load_module(const char *name)
{
	char path[160]; snprintf(path, sizeof path, "/lib/modules/%s", name);
	int fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0) { status("modul yok: %s", name); return -1; }
	long r = syscall(SYS_finit_module, fd, "", 0); int e = errno;
	close(fd);
	if (r == 0) status("modul yuklendi: %s", name);
	else if (e == EEXIST) status("modul zaten var: %s", name);
	else status("modul HATA %s: %s", name, strerror(e));
	return r == 0 || e == EEXIST ? 0 : -1;
}

/* collect block devices whose GPT PARTNAME equals one of the names (priority order) */
static int find_by_partname(const char *const *names, int nn, char devs[][48], int max)
{
	int cnt = 0;
	for (int k = 0; k < nn && cnt < max; k++) {
		DIR *d = opendir("/sys/class/block"); struct dirent *e;
		if (!d) return cnt;
		while ((e = readdir(d)) && cnt < max) {
			if (e->d_name[0] == '.') continue;
			char up[128], ln[160], pn[64] = "";
			snprintf(up, sizeof up, "/sys/class/block/%s/uevent", e->d_name);
			FILE *f = fopen(up, "r"); if (!f) continue;
			while (fgets(ln, sizeof ln, f)) if (!strncmp(ln, "PARTNAME=", 9)) { snprintf(pn, sizeof pn, "%s", ln + 9); pn[strcspn(pn, "\r\n")] = 0; }
			fclose(f);
			if (pn[0] && !strcasecmp(pn, names[k])) snprintf(devs[cnt++], 48, "/dev/%s", e->d_name);
		}
		closedir(d);
	}
	return cnt;
}

static int dir_blocks_present(void)
{
	DIR *d = opendir("/sys/class/block"); struct dirent *e; int n = 0;
	if (!d) return 0;
	while ((e = readdir(d))) if (e->d_name[0] != '.' && strncmp(e->d_name, "loop", 4) && strncmp(e->d_name, "ram", 3)) n++;
	closedir(d); return n;
}

/* An init inside the new root is often an ABSOLUTE symlink (Alpine: /sbin/init -> /bin/busybox,
 * Debian: /sbin/init -> /lib/systemd/systemd).  access() would resolve that against the CURRENT
 * root (the initramfs) and wrongly fail, so only check that the entry exists (lstat). */
static int init_exists(const char *path)
{
	struct stat st;
	if (lstat(path, &st) != 0) return 0;
	if (S_ISLNK(st.st_mode)) return 1;                 /* target lives in the new root */
	return S_ISREG(st.st_mode) && (st.st_mode & 0111);
}

static const char *find_init(const char *root, const char *forced)
{
	static char found[200];
	static const char *const cand[] = { "/sbin/init", "/usr/sbin/init", "/lib/systemd/systemd", "/usr/lib/systemd/systemd", "/bin/init", NULL };
	if (forced && forced[0]) {
		snprintf(found, sizeof found, "%s%s", root, forced);
		return init_exists(found) ? forced : NULL;
	}
	for (int i = 0; cand[i]; i++) { snprintf(found, sizeof found, "%s%s", root, cand[i]); if (init_exists(found)) return cand[i]; }
	return NULL;
}

/* ext4 superblock: magic 0xEF53 at 0x38, volume label (16 bytes) at 0x78 */
static int ext4_label(const char *dev, char *label /* >= 17 bytes */)
{
	unsigned char sb[1024];
	int fd = open(dev, O_RDONLY | O_CLOEXEC);
	if (fd < 0) return 0;
	ssize_t r = pread(fd, sb, sizeof sb, 1024);
	close(fd);
	if (r != (ssize_t)sizeof sb || sb[0x38] != 0x53 || sb[0x39] != 0xEF) return 0;
	memcpy(label, sb + 0x78, 16); label[16] = 0;
	return 1;
}

static int skip_blockname(const char *n)
{
	return n[0] == '.' || !strncmp(n, "loop", 4) || !strncmp(n, "ram", 3) || strstr(n, "boot") || strstr(n, "rpmb");
}

static int dev_listed(char devs[][48], int cnt, const char *dev)
{
	for (int i = 0; i < cnt; i++) if (!strcmp(devs[i], dev)) return 1;
	return 0;
}

/* devices whose ext4 label equals `label` (works whatever the partition is called) */
static int find_by_label(const char *label, char devs[][48], int cnt, int max)
{
	DIR *d = opendir("/sys/class/block"); struct dirent *e;
	if (!d) return cnt;
	while ((e = readdir(d)) && cnt < max) {
		char dev[48], lab[17];
		if (skip_blockname(e->d_name)) continue;
		snprintf(dev, sizeof dev, "/dev/%s", e->d_name);
		if (ext4_label(dev, lab) && !strcmp(lab, label) && !dev_listed(devs, cnt, dev)) snprintf(devs[cnt++], 48, "%s", dev);
	}
	closedir(d);
	return cnt;
}

static int collect_candidates(const char *want, char devs[][48], int max)
{
	int nd = 0;
	if (!strcmp(want, "auto")) {
		static const char *const names[] = { "ROOTFS", "LINUX", "USERDATA", "SYSTEM", "CACHE", "HIDDEN" };
		char byname[8][48]; int nn;
		nd = find_by_label("ROOTFS", devs, 0, max);               /* 1. ext4 label ROOTFS, any partition */
		nn = find_by_partname(names, 6, byname, 8);               /* 2. GPT partition names */
		for (int i = 0; i < nn && nd < max; i++) if (!dev_listed(devs, nd, byname[i])) snprintf(devs[nd++], 48, "%s", byname[i]);
	} else if (!strncmp(want, "LABEL=", 6)) {
		nd = find_by_label(want + 6, devs, 0, max);
	} else if (!strncmp(want, "PARTNAME=", 9)) {
		const char *nm[1] = { want + 9 }; nd = find_by_partname(nm, 1, devs, max);
	} else if (access(want, F_OK) == 0) { snprintf(devs[0], 48, "%s", want); nd = 1; }
	return nd;
}

/* read one 32-bit MMIO register through /dev/mem (diagnostics only) */
static int rd32(unsigned long pa, unsigned *v)
{
	static int fd = -2;
	if (fd == -2) fd = open("/dev/mem", O_RDONLY | O_SYNC);
	if (fd < 0) return -errno;
	void *m = mmap(NULL, 4096, PROT_READ, MAP_SHARED, fd, (off_t)(pa & ~4095UL));
	if (m == MAP_FAILED) return -errno;
	*v = *(volatile unsigned *)((char *)m + (pa & 4095UL));
	munmap(m, 4096);
	return 0;
}

static void fmt_regs(char *out, size_t n, const char *tag, const char *const *nm, const unsigned long *pa, int cnt)
{
	size_t o = (size_t)snprintf(out, n, "%s", tag);
	for (int i = 0; i < cnt && o + 20 < n; i++) {
		unsigned v = 0; int r = rd32(pa[i], &v);
		if (r) o += (size_t)snprintf(out + o, n - o, " %s=ERR%d", nm[i], -r);
		else   o += (size_t)snprintf(out + o, n - o, " %s=%08x", nm[i], v);
	}
}

/* on-screen diagnostics: block devices (size, GPT name, ext4 label) + kernel mmc/block messages */
static void diag_dump(const char *why)
{
	static char L[80][100]; int n = 0;
	static char kb[131072];
	snprintf(L[n++], 100, "TANI: %s", why);
	DIR *d = opendir("/sys/class/block"); struct dirent *e;
	snprintf(L[n++], 100, "blok aygitlari (ad / MB / GPT adi / ext4 etiketi):");
	while (d && (e = readdir(d)) && n < 14) {
		char up[128], ln[160], pn[64] = "-", sz[32] = "0", dev[48], lab[17] = "";
		if (e->d_name[0] == '.' || !strncmp(e->d_name, "loop", 4) || !strncmp(e->d_name, "ram", 3)) continue;
		snprintf(up, sizeof up, "/sys/class/block/%s/size", e->d_name);
		FILE *f = fopen(up, "r"); if (f) { if (fgets(sz, sizeof sz, f)) sz[strcspn(sz, "\r\n")] = 0; fclose(f); }
		snprintf(up, sizeof up, "/sys/class/block/%s/uevent", e->d_name);
		f = fopen(up, "r");
		if (f) { while (fgets(ln, sizeof ln, f)) if (!strncmp(ln, "PARTNAME=", 9)) { snprintf(pn, sizeof pn, "%s", ln + 9); pn[strcspn(pn, "\r\n")] = 0; } fclose(f); }
		snprintf(dev, sizeof dev, "/dev/%s", e->d_name);
		int is_ext4 = !(strstr(e->d_name, "boot") || strstr(e->d_name, "rpmb")) && ext4_label(dev, lab);
		snprintf(L[n++], 100, "%-14s %6llu  %-14s %s", e->d_name, strtoull(sz, NULL, 10) / 2048, pn,
			 is_ext4 ? (lab[0] ? lab : "ext4, etiket yok") : "-");
	}
	if (d) closedir(d);
	{	/* controller + clock registers: dwmmc0 @0x13540000, CMU_TOP @0x10010000, CMU_MIF @0x10430000 */
		static const char *const n1[] = { "CTRL", "CLKDIV", "CLKSRC", "CLKENA", "CTYPE", "RINTSTS", "STATUS", "FIFOTH", "UHS", "CLKSEL" };
		static const unsigned long a1[] = { 0x13540000UL, 0x13540008UL, 0x1354000CUL, 0x13540010UL, 0x13540018UL, 0x13540044UL, 0x13540048UL, 0x1354004CUL, 0x13540074UL, 0x1354009CUL };
		static const char *const n2[] = { "SEL_FSYS0", "DIV_FSYS0", "SEL_TOP0", "SEL_TOP1", "SEL_TOP2" };
		static const unsigned long a2[] = { 0x10010220UL, 0x10010620UL, 0x10010200UL, 0x10010204UL, 0x10010208UL };
		static const char *const n3[] = { "BUS_PLL0", "BUS_PLL1", "MEDIA_PLL0" };
		static const unsigned long a3[] = { 0x10430130UL, 0x10430134UL, 0x10430120UL };
		snprintf(L[n++], 100, "kayitlar (dwmmc0 / CMU_TOP / CMU_MIF):");
		if (access("/sys/bus/platform/devices/13540000.mmc", F_OK) == 0) {   /* only on the J7 device tree */
			fmt_regs(L[n], 100, "MMC", n1, a1, 5); n++;
			fmt_regs(L[n], 100, "MMC", n1 + 5, a1 + 5, 5); n++;
			fmt_regs(L[n], 100, "TOP", n2, a2, 5); n++;
			fmt_regs(L[n], 100, "MIF", n3, a3, 3); n++;
		} else snprintf(L[n++], 100, "  (13540000.mmc aygiti yok: kayit okunmadi)");
	}
	snprintf(L[n++], 100, "cekirdek mmc/blok mesajlari (hata seli ayri):");
	long len = syscall(SYS_syslog, 3, kb, (int)sizeof kb - 1);
	if (len > 0) {
		kb[len] = 0;
		static char *lines[1500]; int nl = 0;
		for (char *q = strtok(kb, "\n"); q && nl < 1500; q = strtok(NULL, "\n")) lines[nl++] = q;
		static char *keep[16], *flood[3]; int nk = 0, nf = 0;
		for (int i = 0; i < nl; i++) {
			char *q = lines[i];
			int is_flood = strstr(q, "I/O error") || strstr(q, "Buffer I/O") || strstr(q, "callbacks suppressed") || strstr(q, "logical block");
			int rel = strstr(q, "mmc") || strstr(q, "dw_") || strstr(q, "mshc") || strstr(q, "GPT") || strstr(q, "artition") || strstr(q, "EXT4") || strstr(q, "ext4") || strstr(q, "timeout") || strstr(q, "CRC") || strstr(q, "tuning");
			if (is_flood) { if (nf < 3) flood[nf++] = q; }
			else if (rel) { if (nk == 16) { memmove(keep, keep + 1, 15 * sizeof keep[0]); nk--; } keep[nk++] = q; }
		}
		for (int i = 0; i < nk && n < 76; i++) snprintf(L[n++], 100, "%.88s", keep[i]);
		if (!nk) snprintf(L[n++], 100, "  (mmc ile ilgili mesaj yok)");
		if (nf) snprintf(L[n++], 100, "-- ilk hata ornekleri:");
		for (int i = 0; i < nf && n < 78; i++) snprintf(L[n++], 100, "%.88s", flood[i]);
	} else snprintf(L[n++], 100, "  (kernel logu okunamadi: %s)", strerror(errno));
	for (int i = 0; i < n; i++) { char m[130]; snprintf(m, sizeof m, "[j7init] %s\n", L[i]); logmsg(m); }
	if (!back) return;
	rect(0, 0, W, H, rgb(0, 0, 0));
	header("ProjectEku TANI");
	for (int i = 0; i < n && i < 66; i++) text(8, 90 + i * 17, 1, i == 0 ? rgb(255, 220, 120) : rgb(235, 235, 235), L[i]);
	flip();
}

static void rootfs_attempt(void)
{
	char want[96], forced[96] = "";
	FILE *f = fopen("/proc/cmdline", "r");
	if (f) { size_t n = fread(cmdline, 1, sizeof cmdline - 1, f); cmdline[n] = 0; fclose(f); }
	if (!cmd_get("eku.root", want, sizeof want)) return;
	cmd_get("eku.init", forced, sizeof forced);
	status("rootfs modu: eku.root=%s", want);

	/* 1. storage driver modules */
	FILE *ml = fopen("/lib/modules/eku-modules.txt", "r");
	if (ml) { char l[96]; while (fgets(l, sizeof l, ml)) { l[strcspn(l, "\r\n")] = 0; if (l[0]) load_module(l); } fclose(ml); }
	else status("eku-modules.txt yok, modul yuklenmedi");

	/* 2. wait for a block device, then (up to 40 s) for a usable rootfs partition */
	int waited = 0;
	for (; waited < 150 && !dir_blocks_present(); waited++) msleep(200);
	status("blok aygiti: %s (%d.%d sn)", dir_blocks_present() ? "var" : "YOK", waited / 5, (waited % 5) * 2);
	if (!dir_blocks_present()) { diag_dump("blok aygiti yok (eMMC surucusu/denetleyici)"); msleep(45000); return; }

	char devs[16][48]; int nd = 0;
	for (int t = 0; t < 40; t++) {
		nd = collect_candidates(want, devs, 16);
		if (nd) break;
		if (t == 0) status("rootfs bolumu araniyor (etiket ROOTFS / bolum adi), en cok 40 sn...");
		msleep(1000);
	}
	if (!nd) { diag_dump("aday bolum bulunamadi"); msleep(45000); return; }
	status("%d aday bolum", nd);

	/* 4. mount read-only, accept only with an init inside */
	for (int i = 0; i < nd; i++) {
		status("deneniyor: %s", devs[i]);
		if (mount(devs[i], "/mnt", "ext4", MS_RDONLY, NULL) != 0) { status("  ext4 mount HATA: %s", strerror(errno)); continue; }
		const char *init = find_init("/mnt", forced);
		if (!init) { status("  init yok, atlandi"); umount("/mnt"); continue; }
		status("  rootfs tamam, init=%s", init);
		if (mount(NULL, "/mnt", NULL, MS_REMOUNT, NULL) == 0) status("  rw olarak baglandi"); else status("  salt okunur kaldi");
		msleep(1500);
		mkdir("/mnt/dev", 0755); mkdir("/mnt/proc", 0755); mkdir("/mnt/sys", 0755);
		if (mount("/dev", "/mnt/dev", NULL, MS_MOVE, NULL) || mount("/proc", "/mnt/proc", NULL, MS_MOVE, NULL) || mount("/sys", "/mnt/sys", NULL, MS_MOVE, NULL))
			status("  MS_MOVE HATA: %s", strerror(errno));
		if (chdir("/mnt") == 0 && mount(".", "/", NULL, MS_MOVE, NULL) == 0 && chroot(".") == 0 && chdir("/") == 0) {
			char *av[2] = { (char *)init, NULL };
			execv(init, av);
		}
		/* only reached on failure */
		logmsg("[j7init] switch_root BASARISIZ\n");
		return;
	}
	diag_dump("adaylar kullanilamadi (mount/init)"); msleep(45000);
}

int main(void)
{
	mount("proc", "/proc", "proc", 0, NULL);
	mount("sysfs", "/sys", "sysfs", 0, NULL);
	mount("devtmpfs", "/dev", "devtmpfs", 0, NULL);
	logmsg("[j7init] basladi\n");

	int fb = -1;
	for (int i = 0; i < 100 && fb < 0; i++) { fb = open("/dev/fb0", O_RDWR); if (fb < 0) msleep(100); }
	if (fb < 0) { logmsg("[j7init] /dev/fb0 yok\n"); rootfs_attempt(); for (;;) pause(); }

	struct fb_var_screeninfo v; struct fb_fix_screeninfo fx;
	ioctl(fb, FBIOGET_VSCREENINFO, &v); ioctl(fb, FBIOGET_FSCREENINFO, &fx);
	W = v.xres; H = v.yres; STRIDE = fx.line_length;
	ro = v.red.offset; go = v.green.offset; bo = v.blue.offset;
	if (v.bits_per_pixel != 32) { logmsg("[j7init] 32bpp degil\n"); for (;;) pause(); }
	fbmem = mmap(NULL, (size_t)STRIDE * H, PROT_READ | PROT_WRITE, MAP_SHARED, fb, 0);
	back = malloc((size_t)W * H * 4);
	if (fbmem == MAP_FAILED || !back) { logmsg("[j7init] mmap hatasi\n"); for (;;) pause(); }

	int mem = open("/dev/mem", O_RDONLY | O_SYNC);
	if (mem >= 0) {
		void *m = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, mem, PIO_BASE);
		if (m != MAP_FAILED) { gpio_dat = (volatile uint32_t *)((uint8_t *)m + BANK_OFF + DAT_OFF); idle_state = *gpio_dat; }
	}
	logmsg(gpio_dat ? "[j7init] tuslar: GPIO okunuyor\n" : "[j7init] tuslar: GPIO yok, otomatik demo\n");

	rootfs_attempt();

	enum { MENU, INFO, COLORS, ANIM } scr = MENU;
	int sel = 0, t = 0, auto_t = 0;
	uint32_t prev = 0;
	for (;;) {
		uint32_t k = read_keys(), edge = k & ~prev; prev = k;
		if (!gpio_dat && ++auto_t % 60 == 0) {            /* ~3 s: otomatik gezinti */
			if (scr == MENU) { scr = (sel == 0) ? INFO : (sel == 1) ? COLORS : ANIM; sel = (sel + 1) % 3; }
			else scr = MENU;
		}
		if (scr == MENU) {
			if (edge & K_DOWN) sel = (sel + 1) % NITEMS;
			if (edge & K_UP)   sel = (sel + NITEMS - 1) % NITEMS;
			if (edge & K_PWR) {
				if (sel == 0) scr = INFO; else if (sel == 1) scr = COLORS; else if (sel == 2) scr = ANIM;
				else { sync(); reboot(RB_AUTOBOOT); }
			}
			screen_menu(sel, gpio_dat != NULL);
		} else {
			if (edge & K_PWR) scr = MENU;
			if (scr == INFO) screen_info(); else if (scr == COLORS) screen_colors(); else screen_anim(t);
		}
		flip(); t++; msleep(50);
	}
}
