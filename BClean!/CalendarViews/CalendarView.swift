//
//  CalendarView.swift
//  BClean!
//
//  Created by Julien Le ber on 29/12/2022.
//


import SwiftUI
import Alamofire
import Firebase
import FirebaseFirestore
import Foundation
import OpenAISwift
import GoogleMobileAds
struct tabView: View{
    var body: some View{
        TabView{
            CalendarViews()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            HouseView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Properties")
                }
            CleanersView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Cleaners")
                }
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }.navigationBarTitle("")
        .navigationBarHidden(true)
    }
}

struct CalendarViews: View {
    @State var sheetShowed:Bool = false
    @ObservedObject var gpt = GPTHelper()
    let db = Firestore.firestore()
    @State var calendarShowed: Int = 0
    //Alert :
    @State var titleAlert:String = ""
    @State var contentAlert:String = ""
    @State var showAlert:Bool = false
    
    //Formatter
    private var formatter = DateFormatter()
    var body: some View {
        VStack{
            ZStack{
                Rectangle()
                    .foregroundStyle((LinearGradient(gradient: Gradient(colors: [Color("orange-gradient"), Color(.white)]), startPoint: .top, endPoint: .bottom)))
                    .ignoresSafeArea()
                    .frame(width: .infinity,height: 100,alignment: .top)
                Text("Your Calendar")
                    .font(.custom("AirbnbCereal_W_XBd", size: 32))
                    .foregroundStyle((LinearGradient(gradient: Gradient(colors: [Color("orange-gradient"), Color("red-gradient")]), startPoint: .top, endPoint: .bottom)))
                    .padding(.top,0)
                
            }
            if userManager.shared.currentUser?.Subscribe == nil {
                AdBannerView(bannerId: "ca-app-pub-2542053766209950/9856587688")
                    .frame(width: UIScreen.main.bounds.width, height: 50)
            }
            Text("Simply tap the new reservations and assign it to a cleaner. You will also have more informations about the reservations shown. ")
                .font(.custom("AirbnbCereal_W_Lt", size: 10))
                .padding(.horizontal)
                .padding(.top,0)
            HStack {
                Button {
                    calendarShowed = 0
                } label: {
                    Text("By Week")
                }.buttonStyle(GradientBackgroundButton(color1: "orange-gradient", color2: "red-gradient"))
                    .padding(.leading,10)
                Button {
                    calendarShowed = 1
                } label: {
                    Text("By month")
                }.buttonStyle(GradientBackgroundButton(color1: "orange-gradient", color2: "red-gradient"))
                Spacer()
                Button(action: {
                    sheetShowed = true
                }, label: {
                    Text("Notify")
                }).buttonStyle(GradientBackgroundButton(color1: "light-green-gradient", color2: "dark-green-gradient"))
                    .padding(.trailing,5)
                    .alert(isPresented: $showAlert, content:
                            {Alert(title: Text(titleAlert),message: Text(contentAlert),dismissButton: .cancel())})
            }.padding(.vertical,10)
                .sheet(isPresented: $sheetShowed) {
                    VStack {
                        Spacer()
                        Text("Sending a message to the cleaners")
                            .font(.custom("AirbnbCereal_W_XBd", size: 22))
                            .foregroundStyle((LinearGradient(gradient: Gradient(colors: [Color("orange-gradient"), Color("red-gradient")]), startPoint: .top, endPoint: .bottom)))
                            .padding(.top,0)
                        Spacer()
                        Text("Default Text message :")
                            .font(.custom("AirbnbCereal_W_XBd", size: 16))
                            .foregroundColor(.gray)
                            .padding(.bottom,15)
                        Text("This is a message from {user_name}, you have a cleaning to do on {menage_endDate} at {house_name}. Please contact your employer if you are available.")
                            .font(.custom("AirbnbCereal_W_Lt", size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                        if let events = userManager.shared.currentUser?.eventStore{
                            ForEach(events, id: \.self) { menage in
                                if menage.cleaner != nil && menage.endDate!.compare(Date()) == .orderedDescending && menage.isConfirmed == 0{
                                    Text("Cleaning on : \(formatter.string(from: menage.endDate!)) with \(menage.cleaner!.name) at \(menage.property.name)")
                                        .foregroundColor(.gray)
                                        .font(.custom("AirbnbCereal_W_Lt", size: 11))
                                }
                            }
                        }
                        Spacer()
                        Button {
                            sendMessage()
                            sheetShowed = false
                        } label: {
                            Text("Confirm")
                        }.buttonStyle(GradientBackgroundButton(color1: "light-green-gradient", color2: "dark-green-gradient"))

                        
                        Spacer()
                    }.presentationDetents([.medium, .large])
                }
            if calendarShowed == 0 {
                WeeklyCalendarView()
            }
            else if calendarShowed == 1 {
                MonthlyCalendarView()
            }
            else if calendarShowed == 2 {
                FocusCleanerCalendarView()
            }
            Spacer()
        }.onAppear{
            self.formatter.dateFormat = "yyyy-MM-dd"
            gpt.setup()
        }
    }
    func translateMessage(text: String, worker: cleaner, completion: @escaping (String) -> Void) {
        let prompt = "Translate me the following message into this language: \(worker.language). To translate: " + text
        gpt.send(text: prompt) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }


    
    
    func sendMessage(){
        formatter.dateFormat = "yyyy-MM-dd"
        let accountSID="AC7cd15eb5e9e12c2d1a9e5d4908911b61"
        let authToken="bed97d7a1579efed31b4cf1c6b8ac765"
        let fromPhoneNumber = "+14068047148"
        if let events = userManager.shared.currentUser?.eventStore{
            events.forEach { menage in
                if menage.cleaner != nil && menage.endDate!.compare(Date()) == .orderedDescending && menage.isConfirmed == 0{
                    
                    //Change menage to pending :
                    menage.isConfirmed = 2
                    db.collection("users").document("\(userManager.shared.currentUser!.id)").collection("events").document("\(menage.id)").updateData(["isConfirmed" : 2]){ err in
                        if let err = err {
                            print("Error updating document: \(err)")
                        } else {
                            print("Document successfully updated")
                        }
                    }
                    ///Send message
                    var toPhoneNumber = "\(menage.cleaner!.phone)"
                    print("\(toPhoneNumber)")
                    var message = "Hello \(menage.cleaner!.name), This is an automatic message from \(userManager.shared.currentUser!.name), you have a cleaning to do on \(formatter.string(from: menage.endDate!)) at the house located at \(menage.property.address). Please click the link to accept or deny it."
                    if menage.options != nil {
                        message = message + "Notes : \(menage.options ?? "")."
                    }
                    let toSend = translateMessage(text: message, worker: menage.cleaner!) { translatedMessage in
                        print("Translated : \(translatedMessage)")
                        let final = translatedMessage + "https://7ntys.github.io/host-site/c.html?i=\(menage.id)&u=\(userManager.shared.currentUser!.id)"
                        let parameters: [String: Any] = [
                            "From": fromPhoneNumber,
                            "To": toPhoneNumber,
                            "Body": final
                        ]
                        let url = "https://api.twilio.com/2010-04-01/Accounts/\(accountSID)/Messages"
                        // Define the HTTP basic authentication header
                        let credential = Data("\(accountSID):\(authToken)".utf8).base64EncodedString()
                        let headers: HTTPHeaders = [
                            "Authorization": "Basic \(credential)"
                        ]
                        AF.request(url, method: .post, parameters: parameters)
                            .authenticate(username: accountSID, password: authToken)
                            .responseJSON { response in
                              debugPrint(response)
                          }
                        titleAlert = "✅Les messages ont bien été envoyés"
                        contentAlert = "Si vos cleaners ne le recoivent pas, vérifier leur numéro de téléphone et le format"
                        showAlert = true
                    }
                }
            }
        }

    }
}

final class GPTHelper: ObservableObject{
    init(){}
    private var client: OpenAISwift?
    func setup(){
        client = OpenAISwift(authToken: "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")
    }
    func send(text:String,completion: @escaping(String) -> Void){
        client?.sendCompletion(with: text,maxTokens: 500) { result in
            switch result{
            case .success(let model):
                let output = model.choices?.first?.text ?? ""
                print("output : \(output)")
                completion(output)
            case .failure:
                print("There is a failure somewhere")
                break
            }
        }
    }
}


struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        tabView()
    }
}
