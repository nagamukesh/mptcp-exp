#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/time.h>

#define PORT 9999
#define BUFFER_SIZE 1000000  // 1MB buffer
#define TARGET_BYTES (100 * 1000000) // 100MB data transfer

int main() {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);
    char buffer[BUFFER_SIZE];
    memset(buffer, 0, BUFFER_SIZE);

    server_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_MPTCP);
    if (server_fd == -1) {
        perror("MPTCP socket creation failed");
        return 1;
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(PORT);
    server_addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) == -1) {
        perror("Bind failed");
        return 1;
    }

    if (listen(server_fd, 5) == -1) {
        perror("Listen failed");
        return 1;
    }

    printf("MPTCP Server listening on port %d...\n", PORT);
    
    client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
    if (client_fd == -1) {
        perror("Accept failed");
        return 1;
    }

    printf("MPTCP connection established!\n");

    // Throughput measurement
    long total_received = 0;
    struct timeval start, end;
    gettimeofday(&start, NULL);

    while (total_received < TARGET_BYTES) {
        int bytes = recv(client_fd, buffer, BUFFER_SIZE, 0);
        if (bytes <= 0) break;
        total_received += bytes;
    }

    gettimeofday(&end, NULL);
    double elapsed_time = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
    double throughput = (total_received * 8) / (elapsed_time * 1e6);  // Mbps

    printf("Received: %ld bytes, Throughput: %.2f Mbps\n", total_received, throughput);

    close(client_fd);
    close(server_fd);
    return 0;
}