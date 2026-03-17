# Grokking Modern System Design Interview: Course Summary

The "Grokking Modern System Design Interview" course is widely considered the gold standard for engineers looking to survive (and thrive in) the grueling whiteboard sessions at Big Tech. Its philosophy has shifted from "memorize these five systems" to "learn the building blocks so you can build anything."

---

## 1. The RESHADED Model
System design interviews can feel like trying to build a plane while it’s flying. The **RESHADED** framework is the course's proprietary mental map to keep you from crashing.

| Phase | Description |
| :--- | :--- |
| **R**equirements | Define what the system does (Functional) and its constraints (Non-functional). |
| **E**stimation | Perform **BOTECs** to understand the scale (Storage, Bandwidth, RPS). |
| **S**torage Schema | Define the data model and choose the right database (SQL vs. NoSQL). |
| **H**igh-Level Design | Draw the core components and how data flows between them. |
| **A**PI Design | Define the endpoints (REST/GraphQL/gRPC) and parameters. |
| **D**–Detailed Design | Zoom into specific components to solve for bottlenecks or single points of failure. |
| **E**valuation | Check your design against the non-functional requirements from step one. |
| **D**istinctive Features | Discuss unique "extra credit" items like security, monitoring, or specialized algorithms. |

---

## 2. The Modular Idea: Components
The "Modern" version of this course treats system design like playing with **LEGOs**. Instead of teaching you how to build "Twitter," it teaches you how to build a "Timeline Service" or a "Notification System" that can be plugged into almost any app.

### List of Components Covered:
* **DNS:** The phonebook of the internet.
* **Load Balancers:** Distributing traffic to keep servers from melting.
* **Databases:** Relational (MySQL/Postgres) and Non-Relational (Cassandra, MongoDB, DynamoDB).
* **Key-Value Stores:** High-speed storage for quick lookups (Redis).
* **Content Delivery Networks (CDN):** Serving static content from the "edge."
* **Messaging Queues:** Decoupling services for asynchronous processing (Kafka, RabbitMQ).
* **Distributed Caching:** Reducing DB load.
* **Rate Limiters:** Throttling "chatty" or malicious users.
* **Blob Storage:** Storing massive files (S3).
* **Distributed ID Generator:** Creating unique IDs across a cluster (Snowflake).
* **Search Indexing:** Fast full-text search (Elasticsearch).

---

## 3. Requirements: Functional vs. Non-Functional
Before you draw a single box, you have to know what you're building.

* **Functional Requirements:** These are the **features**. 
    * *Example:* "The user should be able to upload a 30-second video."
* **Non-Functional Requirements:** These are the **qualities** or "ilities." 
    * *Example:* "The video should be available to viewers with less than 200ms latency."

### Key Non-Functional Requirements:
* **Availability:** Ensuring the system is "up" (aiming for "five nines" or 99.999% uptime).
* **Scalability:** The ability to handle more load by adding more resources (Vertical vs. Horizontal).
* **Reliability:** The system's ability to remain functional even if a few components fail.
* **Consistency:** Ensuring all users see the same data at the same time (Strong vs. Eventual).

---

## 4. BOTECs (Back-of-the-Envelope Calculations)
If you don't do the math, your design is just a guess. BOTECs help you estimate the hardware and bandwidth required.

You'll typically calculate:
1.  **Queries Per Second (QPS):** $\text{Total Requests} / \text{Seconds in a Day}$.
2.  **Storage:** How many Petabytes ($PB$) or Terabytes ($TB$) of data will we accumulate over 5 years?
3.  **Bandwidth:** How much data is moving in and out of our network per second?
4.  **Memory:** How much RAM do we need for our cache if we want to store 20% of the daily traffic?

> **Pro-tip from the course:** Use "Powers of Two" or "Powers of Ten" to make the mental math faster. Nobody cares if the answer is $12.4$, they care if it's closer to $10$ or $100$.

---

## 5. Sharding and Replication
To achieve the "Scalability" and "Availability" mentioned above, the course focuses on how we distribute data.

### Sharding (Data Partitioning)
Sharding is the act of splitting a large dataset into smaller chunks (shards) across multiple machines.
* **Horizontal Sharding:** Storing different rows of a table on different nodes.
* **Partitioning Keys:** Choosing a good key (like `User_ID`) is vital to avoid "Hot Keys" (where one shard gets all the traffic).
* **Consistent Hashing:** A technique used to minimize data movement when a new node is added or removed from the cluster.

### Replication
Replication is the act of storing the same data on multiple nodes.
* **Primary-Secondary (Master-Slave):** The Primary handles writes, while Secondaries handle reads. This improves read scalability.
* **Multi-Primary:** Multiple nodes can handle writes, often used for systems spanning different geographical regions.
* **Quorum:** A technique where a majority of nodes must agree on a data value to ensure consistency in a distributed system.