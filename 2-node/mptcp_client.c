#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

#define PORT 5000
#define BUFFER_SIZE 1024*1024  // 1MB buffer
#define TEST_DURATION 10       // seconds

void perform_throughput_test(int sock_fd) {
    char buffer[BUFFER_SIZE];
    struct timeval start, end;
    long bytes_sent = 0;
    double elapsed_time;

    // Fill buffer with random data
    memset(buffer, 'A', BUFFER_SIZE);

    printf("Starting throughput test...\n");
    gettimeofday(&start, NULL);

    while (1) {
        int bytes = send(sock_fd, buffer, BUFFER_SIZE, 0);
        if (bytes <= 0) break;
        bytes_sent += bytes;

        gettimeofday(&end, NULL);
        elapsed_time = (end.tv_sec - start.tv_sec) + 
                      (end.tv_usec - start.tv_usec) / 1000000.0;

        if (elapsed_time >= TEST_DURATION) break;
    }

    double throughput = (bytes_sent * 8.0) / (elapsed_time * 1000000); // Mbps
    printf("Test Results:\n");
    printf("Bytes sent: %ld\n", bytes_sent);
    printf("Time elapsed: %.2f seconds\n", elapsed_time);
    printf("Throughput: %.2f Mbps\n", throughput);
}


int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <server_ip>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int sock_fd;
    struct sockaddr_in server_addr;
    char buffer[BUFFER_SIZE];

    // Create MPTCP socket
    if ((sock_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_MPTCP)) < 0) {
        perror("MPTCP socket creation failed");
        exit(EXIT_FAILURE);
    }

    // Configure server address
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(PORT);
    
    if (inet_pton(AF_INET, argv[1], &server_addr.sin_addr) <= 0) {
        perror("Invalid address");
        exit(EXIT_FAILURE);
    }

    // Connect to server
    if (connect(sock_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("Connection failed");
        exit(EXIT_FAILURE);
    }

    printf("Connected to server at %s:%d\n", argv[1], PORT);
    perform_throughput_test(sock_fd);
    close(sock_fd);
    return 0;
}