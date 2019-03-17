# Remove Appx Apps

These scripts remove various AppX / UWP / Windows Store applications from an online image. Windows 10 devices come with various built-in AppX applications. While these applications can be targeted for removal by MDM tools, they are often not removed in a timely manner. Additionally, some AppX applications are not available in the Microsoft Store for Business and therefore cannot be targeted. 

These scripts will remove AppX provisioned in the system and user contexts. Apps can be targeted with a blacklist or a whitelist of applications. Take care if using the whitelist approach so that 
