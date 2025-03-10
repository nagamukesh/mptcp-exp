#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

#define PORT 5000
#define BUFFER_SIZE 1024*1024  // 1MB buffer for better throughput
#define TEST_DURATION 10       // Test duration in seconds

void perform_throughput_test(int client_fd) {
    char buffer[BUFFER_SIZE];
    struct timeval start, end;
    long bytes_received = 0;
    double elapsed_time, throughput;

    printf("Starting throughput test...\n");
    gettimeofday(&start, NULL);

    while (1) {
        int bytes = recv(client_fd, buffer, BUFFER_SIZE, 0);
        if (bytes <= 0) break;
        bytes_received += bytes;

        gettimeofday(&end, NULL);
        elapsed_time = (end.tv_sec - start.tv_sec) + 
                      (end.tv_usec - start.tv_usec) / 1000000.0;

        if (elapsed_time >= TEST_DURATION) break;
    }

    throughput = (bytes_received * 8.0) / (elapsed_time * 1000000); // Mbps
    printf("Test Results:\n");
    printf("Bytes received: %ld\n", bytes_received);
    printf("Time elapsed: %.2f seconds\n", elapsed_time);
    printf("Throughput: %.2f Mbps\n", throughput);
}


int main() {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);
    char buffer[BUFFER_SIZE];

    // Create MPTCP socket
    if ((server_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_MPTCP)) < 0) {
        perror("MPTCP socket creation failed");
        exit(EXIT_FAILURE);
    }

    // Enable address reuse
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("setsockopt failed");
        exit(EXIT_FAILURE);
    }

    // Configure server address
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);  // Listen on all interfaces
    server_addr.sin_port = htons(PORT);

    // Bind socket
    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }

    // Listen for connections
    if (listen(server_fd, 5) < 0) {
        perror("Listen failed");
        exit(EXIT_FAILURE);
    }

    printf("MPTCP Server listening on port %d\n", PORT);

    while (1) {
        printf("Waiting for connections...\n");
        
        // Accept connection
        if ((client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len)) < 0) {
            perror("Accept failed");
            continue;
        }

        printf("New connection from %s:%d\n", 
            inet_ntoa(client_addr.sin_addr), 
            ntohs(client_addr.sin_port));

     // Perform throughput test
     perform_throughput_test(client_fd);

     close(client_fd);
 }

 close(server_fd);
 return 0;
}
