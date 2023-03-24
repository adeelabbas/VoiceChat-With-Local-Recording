//
//  KeyCenter.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

struct KeyCenter {
    
    /**
     Agora APP ID.
     Agora assigns App IDs to app developers to identify projects and organizations.
     If you have multiple completely separate apps in your organization, for example built by different teams,
     you should use different App IDs.
     */
    static let AppId: String = ""

    /**
     Certificate.
     Agora provides App certificate to generate Token. You can deploy and generate a token on your server,
     or use the console to generate a temporary token.
     */
    static let Certificate: String? = ""
    
    static var Token: String? = nil
}
