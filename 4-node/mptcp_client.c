#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/time.h>

#define BUFFER_SIZE 1000000  // 1MB buffer
#define TARGET_BYTES (100 * 1000000) // 100MB data transfer

int main() {
    int sockfd;
    struct sockaddr_in server_addr;
    char buffer[BUFFER_SIZE];
    memset(buffer, 'A', BUFFER_SIZE);

    sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_MPTCP);
    if (sockfd == -1) {
        perror("MPTCP socket creation failed");
        return 1;
    }
    
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(9999);
    inet_pton(AF_INET, "10.0.1.2", &server_addr.sin_addr);

    if (connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        perror("MPTCP connection failed");
        close(sockfd);
        return 1;
    }

    printf("MPTCP connection established!\n");

    // Throughput measurement
    long total_sent = 0;
    struct timeval start, end;
    gettimeofday(&start, NULL);

    while (total_sent < TARGET_BYTES) {
        int bytes = send(sockfd, buffer, BUFFER_SIZE, 0);
        if (bytes <= 0) break;
        total_sent += bytes;
    }

    gettimeofday(&end, NULL);
    double elapsed_time = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1e6;
    double throughput = (total_sent * 8) / (elapsed_time * 1e6);  // Mbps

    printf("Sent: %ld bytes, Throughput: %.2f Mbps\n", total_sent, throughput);

    close(sockfd);
    return 0;
}