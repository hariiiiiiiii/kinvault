# Kinvault - Your Family's Digital Memory Chest

[![GitHub stars](https://img.shields.io/github/stars/hariiiiiiiii/kinvault)](https://github.com/hariiiiiiiii/kinvault)
[![License](https://img.shields.io/github/license/hariiiiiiiii/kinvault)](https://github.com/hariiiiiiiii/kinvault/blob/main/LICENSE)
[![Built with Flutter](https://img.shields.io/badge/Flutter-blue)](https://flutter.dev/)
[![Powered by PocketBase](https://img.shields.io/badge/PocketBase-orange)](https://pocketbase.io/)

## Introduction 

Kinvault is a Flutter application designed to securely store and share your precious family photos and memories. Built with a focus on privacy and ease of use, Kinvault provides a centralized location for your digital photo album, accessible only to those you trust.  It leverages PocketBase for backend functionality, offering a streamlined and scalable solution.

## Features 

*   **Secure Photo Storage:**  Utilizes PocketBase for secure storage of your photos.
*   **User Authentication:**  Robust authentication system to protect your memories.
*   **Easy Upload:**  Upload photos directly from your device's gallery or camera.
*   **Photo Listing:** View all uploaded photos in a clean and organized list.
*   **Caching:** Uses `cached_network_image` for faster loading and reduced bandwidth usage.
*   **.env Configuration:** Uses `.env` files to manage sensitive configuration details like your PocketBase server URL safely and separately from the codebase.
*   **Riverpod State Management:** Predictable state management for a smooth user experience.
*   **GoRouter Navigation:**  Declarative and type-safe navigation.

## Installation 

1.  **Clone the Repository:**

    ```bash
    git clone https://github.com/hariiiiiiiii/kinvault.git
    cd kinvault/app
    ```

2.  **Install Dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Configure PocketBase:**

    *   You'll need a running instance of [PocketBase](https://pocketbase.io/).  You can download and run it locally or use a hosted service.
    *   Create a new PocketBase app.
    *   Ensure that the `api` settings are correct, and you've enabled CORS if needed.
    *   Create a `.env` file in the `app` directory and add your PocketBase server IP address:

        ```
        SERVER_IP=your_pocketbase_ip_address
        ```

        Replace `your_pocketbase_ip_address` with the actual IP address or domain name of your PocketBase server.

4.  **Run the Application:**

    ```bash
    flutter run
    ```

## Usage 

1.  **Launch the App:**  Run the Flutter application on your desired device or emulator.
2.  **Login/Register:**  Use the login screen to access your Kinvault account. If you don't have one, create a new account from pocketbase superuser dashboard at ``` http://127.0.0.1:8090/_/```.
3.  **Upload Photos:**  Navigate to the home screen and use the upload button to select photos from your device.
4.  **View Photos:**  Uploaded photos will be displayed in a list on the home screen.

## Contributing 

We welcome contributions to Kinvault!  Here's how you can get involved:

1.  **Fork the Repository:** Create a fork of this repository on GitHub.
2.  **Create a Branch:**  Create a new branch for your feature or bug fix.
3.  **Make Changes:**  Implement your changes and ensure they are well-documented.
4.  **Submit a Pull Request:**  Submit a pull request to the main branch, describing your changes in detail.

Please follow these guidelines:

*   **Code Style:**  Adhere to the Flutter style guide.
*   **Testing:**  Include unit tests for your changes.
*   **Documentation:**  Update the documentation as needed.

## License 

Kinvault is licensed under the [MIT License](https://github.com/hariiiiiiiii/kinvault/blob/main/LICENSE).  See the [LICENSE](https://github.com/hariiiiiiiii/kinvault/blob/main/LICENSE) file for more information.

##  Give it a ⭐!

If you find Kinvault useful or appreciate the effort put into this project, please consider giving it a star on GitHub!  It helps us reach a wider audience and encourages further development.


## License
This project is licensed under the **MIT** License.

---
GitHub Repo: https://github.com/hariiiiiiiii/kinvault
