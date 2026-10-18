#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <util.h>
#include <string.h>

static void print_bytes(const char *label, const char *bytes, ssize_t count) {
	printf("%s (%zd bytes):", label, count);
	for (ssize_t i = 0; i < count; i++) {
		printf(" %02x", (unsigned char)bytes[i]);
	}
	printf("\n");
}

int main(void) {
	int master_fd;
	int slave_fd;

	if (openpty(&master_fd, &slave_fd, NULL, NULL, NULL) == -1 ) {
		perror("openpty");
		return EXIT_FAILURE;
	}

	printf("master fd: %d\n", master_fd);
	printf("slave fd: %d\n", slave_fd);
	printf("slave name: %s\n", ttyname(slave_fd));

	const char *typed_text = "hi\n";
	char buffer[64];
	ssize_t count;

	write(master_fd, typed_text, strlen(typed_text));

	count = read(slave_fd, buffer, sizeof buffer);
	print_bytes("slave received", buffer, count);

	close(master_fd);
	close(slave_fd);
	return EXIT_SUCCESS;
}
