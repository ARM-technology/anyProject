package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

const dirPath = "DataJson"

type UserData struct {
	IDCoupon string `json:"idcoupon"`
	Name     string `json:"name,omitempty"`
	Phone    string `json:"phone,omitempty"`
	Monay    int    `json:"monay,omitempty"`
	Counter  int    `json:"counter,omitempty"`
}

func main() {
	// إنشاء مجلد البيانات إذا لم يكن موجود
	if err := os.MkdirAll(dirPath, os.ModePerm); err != nil {
		log.Printf("فشل في إنشاء مجلد البيانات: %v", err)
	}

	// إضافة عميل جديد
	http.HandleFunc("/add", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "الطريقة غير مسموحة", http.StatusMethodNotAllowed)
			return
		}

		var data UserData
		err := json.NewDecoder(r.Body).Decode(&data)
		if err != nil {
			http.Error(w, "خطأ في قراءة البيانات", http.StatusBadRequest)
			return
		}

		if data.IDCoupon == "" {
			http.Error(w, "يجب توفير كود الكوبون", http.StatusBadRequest)
			return
		}

		// تحقق من عدم وجود الكوبون مسبقاً
		if _, err := getDatajson(data.IDCoupon); err == nil {
			http.Error(w, "الكوبون موجود مسبقاً", http.StatusConflict)
			return
		}

		// تعيين العداد للبيانات الجديدة
		data.Counter = 1

		err = saveDataJson(data)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)
		w.Write([]byte("تمت إضافة البيانات بنجاح"))
		log.Printf("تم إضافة عميل: %s", data.IDCoupon)
	})

	// جلب بيانات عميل
	http.HandleFunc("/get", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, "يجب توفير ID", http.StatusBadRequest)
			return
		}

		// للفحص فقط
		if id == "test" {
			w.Write([]byte("الخادم يعمل"))
			return
		}

		data, err := getDatajson(id)
		if err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
		log.Printf("تم جلب بيانات: %s", id)
	})

	// تحديث مبلغ العميل
	http.HandleFunc("/update", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "الطريقة غير مسموحة", http.StatusMethodNotAllowed)
			return
		}

		var newData UserData
		err := json.NewDecoder(r.Body).Decode(&newData)
		if err != nil {
			http.Error(w, "خطأ في قراءة البيانات", http.StatusBadRequest)
			return
		}

		if newData.IDCoupon == "" {
			http.Error(w, "يجب توفير كود الكوبون", http.StatusBadRequest)
			return
		}

		err = updateDatajson(newData)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Write([]byte("تمت تعديل البيانات بنجاح"))
		log.Printf("تم تحديث: %s", newData.IDCoupon)
	})

	fmt.Println("🚀 الخادم يعمل على المنفذ 8080...")
	fmt.Println("📁 مجلد البيانات:", dirPath)

	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal("فشل تشغيل الخادم:", err)
	}
}

func saveDataJson(data UserData) error {
	fileName := fmt.Sprintf("%s.json", data.IDCoupon)
	filePath := filepath.Join(dirPath, fileName)

	// تحقق من عدم وجود الملف
	if _, err := os.Stat(filePath); !os.IsNotExist(err) {
		return fmt.Errorf("الكوبون موجود مسبقاً")
	}

	jsonBytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("فشل تحويل البيانات: %v", err)
	}

	err = os.WriteFile(filePath, jsonBytes, 0644)
	if err != nil {
		return fmt.Errorf("فشل حفظ الملف: %v", err)
	}

	fmt.Printf("✅ تم حفظ: %s\n", filePath)
	return nil
}

func getDatajson(id string) (*UserData, error) {
	filePath := filepath.Join(dirPath, fmt.Sprintf("%s.json", id))

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return nil, fmt.Errorf("الملف غير موجود")
	}

	fileBytes, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("فشل قراءة الملف: %v", err)
	}

	var data UserData
	err = json.Unmarshal(fileBytes, &data)
	if err != nil {
		return nil, fmt.Errorf("فشل تحويل JSON: %v", err)
	}

	return &data, nil
}

func updateDatajson(newData UserData) error {
	fileName := fmt.Sprintf("%s.json", newData.IDCoupon)
	filePath := filepath.Join(dirPath, fileName)

	// تحقق من وجود الملف
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("الملف غير موجود للتحديث")
	}

	fileBytes, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("فشل قراءة الملف: %v", err)
	}

	var existingData UserData
	err = json.Unmarshal(fileBytes, &existingData)
	if err != nil {
		return fmt.Errorf("فشل تحويل JSON: %v", err)
	}

	// زيادة العداد
	existingData.Counter++

	// إضافة المبلغ الجديد
	if newData.Monay > 0 {
		existingData.Monay += newData.Monay
	}

	updateJson, err := json.MarshalIndent(existingData, "", "  ")
	if err != nil {
		return fmt.Errorf("فشل تحويل البيانات: %v", err)
	}

	err = os.WriteFile(filePath, updateJson, 0644)
	if err != nil {
		return fmt.Errorf("فشل حفظ الملف: %v", err)
	}

	fmt.Printf("✅ تم تحديث: %s\n", filePath)
	return nil
}
