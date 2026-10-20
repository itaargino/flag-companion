#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>

int main(void) {
	printf("before fork: pid %d\n", getpid());

	pid_t child_pid = fork();
	if (child_pid == -1) {
		perror("fork");
		return EXIT_FAILURE;
	}

	if (child_pid == 0) {
		printf("child: pid %d, parent %d\n", getpid(), getppid());

		int file_fd = open("/tmp/listing.txt", O_WRONLY | O_CREAT | O_TRUNC, 0600);
		if (file_fd == -1) {
			perror("open");
			return EXIT_FAILURE;
		}
		dup2(file_fd, STDOUT_FILENO);
		close(file_fd);

		execlp("ls", "ls", "-l", NULL);
		perror("execlp");
		return EXIT_FAILURE;
	}

	printf("parent: pid %d, created child %d\n", getpid(), child_pid);
	waitpid(child_pid, NULL, 0);
	printf("parent: child finished\n");
	return EXIT_SUCCESS;
}


