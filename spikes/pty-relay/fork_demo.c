#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void) {
	printf("before fork: pid %d\n", getpid());

	pid_t child_pid = fork();
	if (child_pid == -1) {
		perror("fork");
		return EXIT_FAILURE;
	}

	if (child_pid == 0) {
		printf("child: pid %d, parent %d\n", getpid(), getppid());
		return EXIT_SUCCESS;
	}

	printf("parent: pid %d, created child %d\n", getpid(), child_pid);
	waitpid(child_pid, NULL, 0);
	printf("parent: child finished\n");
	return EXIT_SUCCESS;
}


