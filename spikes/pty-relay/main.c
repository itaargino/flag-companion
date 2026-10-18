#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <util.h>

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

	close(master_fd);
	close(slave_fd);
	return EXIT_SUCCESS;
}
