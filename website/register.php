<?php
header('Content-Type: application/json');

$response = array();

// Database connection details (replace with your RDS endpoint, username, password)
// IMPORTANT: These values will come from Terraform outputs
$db_host = 'YOUR_RDS_ENDPOINT'; // e.g., piano-teaching-db.c0xxxxxxxxx.us-east-1.rds.amazonaws.com
$db_user = 'admin';
$db_pass = 'YOUR_DB_PASSWORD'; // Use the password you set in Terraform
$db_name = 'pianodb'; // The database we will create

// Create connection
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);

// Check connection
if ($conn->connect_error) {
    $response['success'] = false;
    $response['message'] = "Database Connection failed: " . $conn->connect_error;
    http_response_code(500); // Internal Server Error
    echo json_encode($response);
    exit();
}

// Get the POST data
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if ($_SERVER["REQUEST_METHOD"] == "POST" && $data) {
    $name    = $conn->real_escape_string($data['name']);
    $address = $conn->real_escape_string($data['address']);
    $mobile  = $conn->real_escape_string($data['mobile']);
    $email   = $conn->real_escape_string($data['email']);

    // SQL to insert data
    $sql = "INSERT INTO registrations (name, address, mobile, email) VALUES (?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssss", $name, $address, $mobile, $email);

    if ($stmt->execute()) {
        $response['success'] = true;
        $response['message'] = "Registration successful!";
    } else {
        $response['success'] = false;
        $response['message'] = "Error: " . $stmt->error;
        http_response_code(500); // Internal Server Error
    }

    $stmt->close();
} else {
    $response['success'] = false;
    $response['message'] = "Invalid request method or data.";
    http_response_code(400); // Bad Request
}

$conn->close();
echo json_encode($response);
?>
